# Backup REST API — Документация

> Статус: **MOCK / Заглушка**
> Этот документ описывает контракт API для бэкапа пользовательских данных.
> Реальная реализация бэкенда — в будущих фазах.

---

## Назначение

Backup API позволяет:
- Сохранять локальные данные (вклады, настройки) на удалённом сервере
- Восстанавливать данные при смене устройства или удалении приложения
- Синхронизировать данные между устройствами одного пользователя

CashOperation и PortfolioPosition не бэкапятся — они поступают из Tradernet API.

---

## Базовый URL

```
https://api.investportfolio.app/api/v1
```

---

## Аутентификация

Все запросы требуют заголовка:

```
Authorization: Bearer <token>
```

Токен — тот же Tradernet-токен, что хранится в Keychain приложения.

Ошибка при неверном токене:
```json
HTTP 401
{
  "error": { "code": 401, "message": "Unauthorized" }
}
```

---

## Эндпоинты

### Вклады (Deposits)

#### `POST /backup/deposits`

Загружает все вклады пользователя на сервер (полная замена).

**Request body:**
```json
{
  "deposits": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "Сбер вклад",
      "bankName": "Сбербанк",
      "amount": 100000.0,
      "currency": "RUB",
      "createdAt": "2025-01-15T10:30:00Z",
      "openDate": "2025-01-15T00:00:00Z",
      "closeDate": "2025-07-15T00:00:00Z",
      "annualInterestRate": 18.5
    }
  ],
  "exportedAt": "2026-04-04T12:00:00Z"
}
```

**Поля:**
| Поле | Тип | Обязательное | Описание |
|------|-----|:---:|---------|
| id | UUID | ✅ | Идентификатор вклада |
| title | String | ✅ | Название |
| bankName | String? | ❌ | Название банка |
| amount | Double | ✅ | Сумма |
| currency | String | ✅ | Код валюты (USD, RUB и т.д.) |
| createdAt | ISO 8601 | ✅ | Дата создания записи |
| openDate | ISO 8601 | ✅ | Дата открытия вклада |
| closeDate | ISO 8601? | ❌ | Дата закрытия (если есть) |
| annualInterestRate | Double | ✅ | Годовая ставка в % |

**Response `200 OK`:**
```json
{
  "status": "ok",
  "depositsCount": 3,
  "backupId": "bkp_abc123",
  "savedAt": "2026-04-04T12:00:00Z"
}
```

---

#### `GET /backup/deposits`

Получает последний бэкап вкладов.

**Response `200 OK`:**
```json
{
  "deposits": [ ... ],
  "exportedAt": "2026-04-04T12:00:00Z",
  "backupId": "bkp_abc123"
}
```

**Response `404 Not Found`:** Нет сохранённого бэкапа.

---

### Настройки (Settings)

#### `POST /backup/settings`

Загружает настройки приложения.

**Request body:**
```json
{
  "settings": {
    "selectedCurrencies": ["USD", "EUR", "RUB"],
    "localeIdentifier": "ru"
  },
  "exportedAt": "2026-04-04T12:00:00Z"
}
```

**Response `200 OK`:**
```json
{
  "status": "ok",
  "backupId": "bkp_def456",
  "savedAt": "2026-04-04T12:00:00Z"
}
```

---

#### `GET /backup/settings`

Получает последний бэкап настроек.

**Response `200 OK`:**
```json
{
  "settings": {
    "selectedCurrencies": ["USD", "EUR", "RUB"],
    "localeIdentifier": "ru"
  },
  "exportedAt": "2026-04-04T12:00:00Z",
  "backupId": "bkp_def456"
}
```

---

### Управление бэкапами

#### `GET /backup`

Список всех бэкапов пользователя.

**Response `200 OK`:**
```json
{
  "backups": [
    {
      "backupId": "bkp_abc123",
      "type": "deposits",
      "itemsCount": 3,
      "savedAt": "2026-04-04T12:00:00Z"
    },
    {
      "backupId": "bkp_def456",
      "type": "settings",
      "savedAt": "2026-04-04T12:00:00Z"
    }
  ]
}
```

---

#### `DELETE /backup`

Удаляет все бэкапы пользователя (для смены аккаунта или отзыва данных).

**Response `200 OK`:**
```json
{
  "status": "ok",
  "message": "All backups deleted"
}
```

---

## Коды ошибок

| HTTP код | Описание |
|----------|---------|
| 200 | Успешно |
| 400 | Неверный запрос (отсутствует поле, неверный формат) |
| 401 | Не авторизован или токен истёк |
| 404 | Бэкап не найден |
| 422 | Валидация провалилась (например, неверная валюта) |
| 429 | Слишком много запросов (rate limit: 10 запросов/мин) |
| 500 | Внутренняя ошибка сервера |

**Стандартный формат ошибки:**
```json
{
  "error": {
    "code": 400,
    "message": "Field 'title' is required"
  }
}
```

---

## Требования к безопасности

- Все запросы только через HTTPS (TLS 1.2+)
- Данные о суммах вкладов рекомендуется шифровать at-rest на сервере (AES-256)
- Хранить бэкап привязанным к userId, не к токену (токен ротируется)
- Rate limiting: 10 запросов/мин на пользователя
- Логи доступа к данным — для аудита

---

## Правила разрешения конфликтов

- **Last-write-wins**: побеждает бэкап с более поздним `exportedAt`
- Устройство всегда имеет право перезаписать серверный бэкап
- При восстановлении пользователю показывается дата последнего бэкапа

---

## Версионирование

- Текущая версия: `v1`
- При изменении схемы данных — новая версия (`v2`)
- `v1` поддерживается минимум 12 месяцев после выхода `v2`

---

## iOS-интеграция (план)

Для реализации в приложении создать:

```
Service/BackupService.swift
  - func backupDeposits(_ deposits: [Deposit]) async throws
  - func restoreDeposits() async throws -> [Deposit]
  - func backupSettings(_ settings: Settings) async throws
  - func restoreSettings() async throws -> Settings

APIClient/BackupAPIClient.swift
  - POST/GET запросы к эндпоинтам выше
  - Использует тот же Bearer-токен из Keychain
```

Кнопка "Создать бэкап" / "Восстановить" — в `SettingsView`.
