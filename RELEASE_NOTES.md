# Release notes — рефакторинг и оптимизация

## Краткое описание (для Release / коммита)

**Рефакторинг:** монолитный `ContentView.swift` (~3200 строк) разбит на 9 файлов (Models, сервисы, UI).  
**Оптимизации:** безопасный cast в MapView, отвязка API от настроек, батчинг запросов к N2YO (до 5 одновременно), время кеша из данных кеша.  
**Исправление:** добавлен `import Combine` в `AppSettings` для корректного соответствия `ObservableObject`.

---

## Однострочное сообщение для коммита

```
refactor: split ContentView into Models/Services/Views, add API batching and safe MapView cast
```

---

## Описание для GitHub Release (можно вставить в описание релиза)

```markdown
## Что изменилось

- **Структура проекта:** код разнесён по файлам — Models, FrequencyStore, AppSettings, SatelliteAPI, LocationManager, CompassManager, GeocoderManager, ContentView (только UI).
- **Безопасность:** в MapView убран force unwrap (`as!`), используется безопасное приведение типа.
- **API:** SatelliteAPI больше не зависит от AppSettings; обновление времени кеша передаётся через замыкание `onCacheUpdated`.
- **Запросы к N2YO:** включён батчинг — одновременно выполняется не более 5 запросов.
- **Кеш:** при загрузке из кеша время последнего обновления берётся из самого кеша.
- **Сборка:** в AppSettings добавлен `import Combine` для корректной работы с `ObservableObject`.

Поведение приложения для пользователя не изменилось.
```
