# Layout

- `ios/Core` - Swift package with all of the iOS app's logic. No SwiftUI, no UIKit. Builds and tests on Linux.
- `ios/App` - SwiftUI views. They read `state` and call `send`. Nothing else.
- `ios/UITests` - gesture tests, for what a screenshot cannot prove.
- `packages/client` - web app (TanStack Start, Cloudflare Workers).
- `packages/server` - API (Fastify, MongoDB, BullMQ).
- `packages/shared`, `packages/task-service` - shared code and the job queue.

Read [`ios/README.md`](ios/README.md) before working on the iOS app.

# Verifying

- iOS logic: `swift test --package-path ios/Core`. Run it before every commit that touches `ios/Core`.
- iOS screens: they only build on macOS. Put `[shots]` in a commit message and CI builds the app, captures every screen in light and dark, and runs the gesture tests. Look at the screenshots before calling a visual change done.
- Web and API: `pnpm build` and the package's own lint and test scripts.

# iOS rules

- Every decision lives in a ViewModel in `ios/Core`: a `State`, an `Action`, one `send`. A view never decides.
- Every screen is reachable through the CLI (`reindoo-cli ls`, `do <action>`). Tests speak that protocol and can do nothing a user cannot.
- All interface text reaches the view through state, from `Copy`, in English, French and Vietnamese.
- Nothing in tests depends on chance or on the clock. Fixtures inject both.
- The user's data is local first. Every write queues its change in the outbox in the same transaction.
- Never read a property while mutating it (`stack.removeLast(stack.count - n)`): Swift stops the app. Take the count first.

# Style

- Comments say why, not what. In this codebase they are written in French.
- Short sentences in prose and commit messages. One idea each.
- Two spaces for indentation, four in Swift. No tabs.
- No secrets in the repository, ever. Configuration comes from the environment; `.env.example` files document the names.
