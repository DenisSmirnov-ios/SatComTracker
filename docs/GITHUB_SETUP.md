# Публикация репозитория на GitHub

## Вариант 1: Репозиторий уже создан (у вас уже есть origin)

Если репозиторий `SatComTracker` уже создан на GitHub (например, `https://github.com/DenisSmirnov-ios/SatComTracker`):

1. Добавьте все новые файлы и закоммитьте:
   ```bash
   cd /Users/smirnovdenis/Desktop/Project/SatComTracker
   git add .
   git status   # проверьте, что в коммит не попали xcuserdata, DerivedData и т.п.
   git commit -m "docs: add README, LICENSE, .gitignore and project structure"
   ```

2. Отправьте изменения на GitHub:
   ```bash
   git push -u origin main
   ```

3. На GitHub откройте репозиторий → **Settings** → по желанию заполните **Description** и **Topics** (например: `ios`, `swift`, `swiftui`, `satellite`, `n2yo`, `satcom`).

---

## Вариант 2: Создать новый репозиторий на GitHub

### Через веб-интерфейс GitHub

1. Зайдите на [github.com](https://github.com) → **New repository**.
2. Укажите:
   - **Repository name:** `SatComTracker`
   - **Description:** `iOS‑приложение для отслеживания спутников SATCOM (азимут, элевация, частоты, компас). N2YO API.`
   - **Public**
   - **Не** ставьте галочки «Add a README» / «Add .gitignore» — они уже есть в проекте.
3. Нажмите **Create repository**.

4. В терминале выполните (подставьте свой username вместо `YOUR_USERNAME`):
   ```bash
   cd /Users/smirnovdenis/Desktop/Project/SatComTracker

   # Если remote origin уже указывает на другой URL — замените его:
   git remote set-url origin https://github.com/YOUR_USERNAME/SatComTracker.git

   git add .
   git status
   git commit -m "docs: add README, LICENSE, .gitignore; refactor project structure"
   git branch -M main
   git push -u origin main
   ```

### Через GitHub CLI (если установлен `gh`)

```bash
cd /Users/smirnovdenis/Desktop/Project/SatComTracker
gh auth login   # если ещё не авторизованы
gh repo create SatComTracker --public --source=. --remote=origin --push --description "iOS‑приложение для отслеживания спутников SATCOM (N2YO API)"
```

---

## После публикации

- В **README** замените `YOUR_USERNAME` на ваш логин GitHub (в URL клонирования), если использовали плейсхолдер.
- Включите **Issues** в настройках репозитория, если нужны багрепорты и идеи.
- При необходимости создайте первый **Release** (тег версии + текст из [RELEASE_NOTES.md](../RELEASE_NOTES.md)).
