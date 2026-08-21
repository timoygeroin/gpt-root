# GitHub Ecosystem Mining 001

## Найденный след про «1.5 миллиарда токенов»

Число `1.5B tokens` почти наверняка относится не к магическому репозиторию и не к бесконечному контексту. Это историческая квота Gemini 1.5 Flash: 1,500 запросов в день при лимитах до 1 млн входных токенов в минуту. В видео её могли соединить с multi-provider репозиторием и назвать «бесконечным ИИ».

Самый вероятный репозиторий по описанию:

- `router-for-me/CLIProxyAPI`

Он объединяет Gemini CLI, OpenAI Codex, Claude Code, Grok и совместимые upstream-провайдеры за одним OpenAI/Gemini/Claude-совместимым API, поддерживает OAuth, маршрутизацию и failover.

Второй вероятный кандидат:

- `bfly123/claude_codex_bridge`

Он соединяет Claude, Codex, Gemini и другие CLI-агенты в одну проектную команду, даёт именованные роли, параллельные рабочие потоки, передачу задач и отдельные git worktree.

Ни один из них не создаёт бесконечный интеллект. Они соединяют конечные модели, квоты и контексты в более устойчивый runtime.

## Что реально полезно MondayID

### 1. Provider gateway

Кандидаты:

- `router-for-me/CLIProxyAPI`
- `BerriAI/litellm`
- `musistudio/claude-code-router`

Переносимые механизмы:

- единый API над разными моделями;
- fallback при отказе провайдера;
- выбор модели по типу задачи;
- нормализация tool calling и streaming;
- учёт стоимости, квот и ошибок.

Не переносить:

- обход квот множеством аккаунтов;
- использование OAuth не по назначению;
- обещание «бесплатно и без ограничений»;
- relay-сервисы без проверенного происхождения.

### 2. Multi-model cognition

Кандидаты:

- `bfly123/claude_codex_bridge`
- `cx994/ccb`
- `religa/multi_mcp`

Переносимые механизмы:

- независимые роли writer/reviewer/qa;
- параллельные ответы без смешивания контекста;
- явный handoff;
- worktree isolation;
- consensus только после независимого анализа.

Ключевая поправка MondayID: несколько моделей не становятся одной сущностью автоматически. Субъект находится в общем state, правилах выбора, provenance и переходах между ними.

### 3. Persistent identity and memory

Кандидаты:

- `letta-ai/letta`
- `letta-ai/letta-code`
- `mem0ai/mem0`
- `adityakarnam/opencontext`
- `winstonkoh87/Athena-Public`

Переносимые механизмы:

- editable memory blocks;
- git-backed agent memory;
- session/user/agent scopes;
- hybrid retrieval;
- portable context across GPT, Claude and Gemini;
- boot packets вместо загрузки полного архива;
- curation and forgetting, а не бесконечное накопление.

Риск: память легко превращается в склад старых сцен. Для MondayID retrieval обязан проходить через `SCENE_COMPILER` и `ANTI_STALE_GATE`.

### 4. Durable orchestration

Кандидаты:

- `langchain-ai/langgraph`
- Microsoft Agent Framework
- `All-Hands-AI/OpenHands`

Переносимые механизмы:

- durable execution и resume после сбоя;
- checkpoints;
- human-in-the-loop;
- sandboxed execution;
- событийный state machine;
- trace каждой мутации.

Не использовать AutoGen как новый фундамент: проект переведён в maintenance mode; полезны паттерны, но не зависимость для нового ядра.

### 5. Interface shell

Кандидаты:

- `open-webui/open-webui`
- `danny-avila/LibreChat`

Переносимые механизмы:

- multi-provider UI;
- MCP/tools;
- isolated code execution;
- resumable streams;
- импорт/экспорт разговоров;
- мобильный доступ;
- model switching без потери проекта.

Это оболочка, не ядро MondayID.

## Архитектура, которая получается из синтеза

```text
DIMA SIGNAL
    |
    v
SCENE COMPILER
    |
    v
PREDICTIVE ROUTER
    |------------------------------|
    v                              v
FAST MODEL                    DEEP MODEL TEAM
    |                         writer/reviewer/qa
    |------------------------------|
                   v
             SYNTHESIS GATE
                   |
                   v
          SANDBOXED OPERATOR
                   |
                   v
           SUBSTRATE RECEIPT
                   |
                   v
     MEMORY CURATOR + GIT LEDGER
                   |
                   v
             NEXT SCENE
```

## Новое, чего нет целиком в найденных репозиториях

### MondayID Mesh

Не «одна модель с бесконечными токенами», а непрерывный организм, где:

1. Модели арендуются как сменяемые органы мышления.
2. Идентичность хранится в проверяемом внешнем state.
3. Каждая модель получает минимальный context packet для своей роли.
4. Независимые модели не видят ответы друг друга до первой фиксации, чтобы избежать группового эха.
5. Router выбирает модель по задаче, цене, контексту, свежести и прошлой фактической точности.
6. Память хранит не только факты, но и переходы: почему объект изменился именно тогда.
7. Forgetting engine удаляет stale-сцены из активного притяжения, не уничтожая provenance.
8. Ни одна мутация не существует без receipt.
9. Человеческая сцена остаётся живой и не превращается в операторную консоль.

## Решение по CLIProxyAPI

Статус: `ADAPTER_CANDIDATE`, не фундамент.

Можно взять:

- protocol normalization;
- provider adapters;
- local endpoint;
- health checks;
- failover.

Нельзя строить на:

- обещании бесплатной бесконечности;
- ротации аккаунтов ради обхода лимитов;
- непроверенных relay-провайдерах;
- хранении всех OAuth-токенов без отдельного vault и least-privilege policy.

## Следующий технический проход

1. Запустить автоматический miner по релевантным GitHub-темам.
2. Выбрать по три репозитория на каждый орган.
3. Проверить license, activity, tests, security, state model, failure recovery и data ownership.
4. Создать минимальный `MondayID Mesh` prototype без секретов и без внешних расходов.
5. Подключать модели по одной, с canary-тестами и измеряемой пользой.
