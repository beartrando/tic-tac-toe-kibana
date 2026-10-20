#!/usr/bin/env bash
# Применяет index templates для логов в Elasticsearch (идемпотентно).
#
# Переменные окружения:
#   ES_URL             — адрес Elasticsearch (по умолчанию http://localhost:9200)
#   RECREATE_INDICES   — true: удалить существующие индексы логов перед применением
#                        шаблонов (шаблон действует только на новые индексы; dev-данные не жалко)
set -euo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

if ! curl -fsS "$ES_URL/_cluster/health" >/dev/null 2>&1; then
    echo "❌ Elasticsearch недоступен: $ES_URL" >&2
    exit 1
fi

if [ "${RECREATE_INDICES:-false}" = "true" ]; then
    for index in service-messages battle-operations; do
        code="$(curl -sS -o /dev/null -w '%{http_code}' -X DELETE "$ES_URL/$index")"
        if [ "$code" = "200" ]; then
            echo "🗑  индекс $index удалён"
        elif [ "$code" = "404" ]; then
            echo "ℹ️  индекс $index отсутствует"
        else
            echo "❌ не удалось удалить индекс $index (HTTP $code)" >&2
            exit 1
        fi
    done
fi

for template in service-messages battle-operations; do
    file="$TEMPLATES_DIR/$template.json"
    if [ ! -f "$file" ]; then
        echo "❌ нет файла шаблона: $file" >&2
        exit 1
    fi

    curl -fsS -X PUT "$ES_URL/_index_template/${template}-template" \
        -H "Content-Type: application/json" \
        --data-binary "@$file" >/dev/null
    echo "✅ index template ${template}-template применён"
done
