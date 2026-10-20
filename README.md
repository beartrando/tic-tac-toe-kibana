# Kibana: просмотр логов сервисов

Provisioning Kibana для просмотра логов tic-tac-toe: Data View, дашборд `Battles`
и index templates Elasticsearch. Всё хранится как код, чтобы стенд поднимался
воспроизводимо, а не создавался руками в UI.

## Состав

```
kibana/
├── import.sh                    # импорт saved objects (+ применение index templates)
├── elastic/
│   ├── apply-templates.sh       # идемпотентно применяет index templates в Elasticsearch
│   └── templates/
│       ├── service-messages.json
│       └── battle-operations.json
└── saved-objects/
    └── battles.ndjson           # Data View, поиски, визуализации, дашборд
```

## Использование

```bash
make kibana-import                       # из корня infra (KIBANA_URL=http://localhost:5601)
KIBANA_URL=http://host:5601 make kibana-import
```

Скрипт:

1. ждёт, пока Kibana ответит `available` (до 120 секунд);
2. применяет index templates (`ES_URL`, по умолчанию `http://localhost:9200`);
3. удаляет прежние версии объектов `battle-trace` / `Battles` (id фиксированы);
4. импортирует `saved-objects/battles.ndjson` с `overwrite=true`.

Экспорт текущего состояния из Kibana (для обновления NDJSON):

```bash
make kibana-export
```

## Что показывает дашборд `Battles`

Data View `battle-trace` = `service-messages,battle-operations`, time field `@timestamp`.

| панель | что показывает |
|---|---|
| Controls | фильтры `battle_id`, `service`, `transport` |
| Battles timeline | гистограмма событий по времени с разбивкой по `service` |
| Messages | таблица транспортных сообщений: время, сервис, направление, транспорт, канал, `track_id`, `battle_id`, payload |
| Operations | группировка по `track_id`: время запроса/ответа и число сообщений одной операции |

## Runtime-поля

В документах `service-messages` нет полей `battle_id` и `transport` верхнего уровня
(они объявлены в mapping, но сервисы их пока не заполняют). Поэтому в Data View
добавлены runtime-поля с другими именами, чтобы не перекрывать mapping:

| runtime-поле | подпись в UI | откуда берётся |
|---|---|---|
| `battleId` | `battle_id` | `payload.battleId`, `payload.id.value`, `payload.move.battleId`, `payload.leave.battleId`, `payload.battle.id` |
| `transportKind` | `transport` | `channel`: `/...` → `grpc`, `ws-...` → `websocket`, строка с пробелом → `http`, иначе `kafka` |

Когда сервисы начнут писать `battle_id`/`transport` в документы, runtime-поля можно
удалить и переключить панели на обычные поля — имена в UI не изменятся.

## Index templates

Шаблоны задают корреляционные поля как `keyword` (иначе динамический mapping делает
`text` + `.keyword`, и агрегации в дашборде ломаются). Шаблон действует только на
новые индексы: существующий индекс нужно пересоздать (в dev данные логов не жалко).

## Ограничения

- Индекс `battle-operations` сейчас не пишется (логгер операций движка удалён при
  рефакторинге), поэтому панель Operations построена по `service-messages` и `track_id`.
- Порты `9200`/`5601` публикуются только в dev (`docker-compose.yml.dist`); в deploy
  они закомментированы, дашборд импортируется внутри сети.
