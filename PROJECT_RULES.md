# Project Rules and Guidelines

Welcome to the project! To ensure consistency, prevent regressions, and make sure past instructions are not forgotten, please abide by the following rules when developing or refactoring this application.

## 1. State Management & Undo Functionality
- **Always Log Rollback Data:** When implementing state changes (Create, Update, Delete), ensure the `previousData` or the full object is logged correctly so it can be rolled back via the app's undo system.
- **Full Object on Delete:** Delete operations must pass the *full object* for logging to allow complete restoration if the user undoes the action.

## 2. UI & Interaction Guidelines
- **Popup/Dialog Management:** After a successful save or a delete confirmation, ensure **all relevant popups and dialogs are closed automatically**. Do not leave stale dialogs on the screen.
- **List Usability:** Screens displaying many entries (e.g., categories, ledgers) should include a Search button.
- **Group Summaries:** In grouped views, ensure category headers explicitly display the calculated group sum amounts.

## 3. Financial Architecture & Ledger
- **Master Wallet System:** strictly adhere to the unified "Master Wallet / Unallocated Pool" architecture. Do not revert to or create separate PME and OTE unallocated budget pools. Transfers should flow correctly through this consolidated pool.
- **Accurate Balance Calculation:** Ensure all transaction types, specifically transfers between different budget pools, are fully accounted for in the ledger view and affect the overall balance accurately.

## 4. Deployment & Versioning
- **Deployment Process:** Always follow the steps outlined in `DEPLOY_GUIDE.md` when pushing updates to the web application.
- **Cache Busting:** Before every web deployment, remember to increment the application version/number to ensure cache busting across browsers.
- **Firebase Hosting:** Final web releases are deployed to Firebase Hosting.

---
*Note to AI Assistant: Read this file before proceeding with major code changes or refactoring to ensure constraints are respected.*
