Project: Memories (iOS)

1. The Vision

"Memories" is a deeply personal social network centered around shared digital scrapbooks.

Core Concept: Users add friends. A confirmed friendship automatically spawns a shared "Book".

Interaction: Users exchange "Letters". When a letter is sent, it becomes a permanent, immutable page in the shared book.

The Canvas: Users create content using a rich canvas (PencilKit for handwriting + draggable/resizable Photos and Text).

The Experience: The goal is high fidelity. The book must feel like a physical object (page curl animations), and the ink/photos must render identically on iPhones and iPads regardless of screen size.

2. Tech Stack & Architecture

Language: Swift 5+

Frameworks: UIKit (Primary for Canvas/Book), SwiftUI (Root/Navigation wrappers), PencilKit, AuthenticationServices.

Backend: Supabase (PostgreSQL, Auth, Storage).

Architecture: MVVM (Model-View-ViewModel).

ViewModels hold business logic, state, and DB calls. They verify data integrity.

ViewControllers handle UI lifecycle and input events.

Models are Codable structs mirroring DB tables or JSON structures.

3. Coding Style Guidelines (CRITICAL)

Goal: Production-ready, maintainable, clean code.

Comments:

Write in English.

Be sparse. Do not comment obvious code (e.g., // Sets the background color).

Comment the WHY, not the WHAT. Explain complex logic or hacks. Write like a senior engineer talking to another senior engineer, not a bot.

Modularity:

The current UI is a placeholder. We will burn it down and redesign it later.

Constraint: Logic must be decoupled from Views. ViewModels must not import UIKit (unless absolutely necessary for UIImage handling).

Safety:

Use guard let for unwrapping. Avoid force unwrapping !.

Handle errors gracefully (do not crash the app on DB failures).

Memory management: Use [weak self] in closures to prevent retain cycles.

4. Database Schema (Supabase/PostgreSQL)

We use a hybrid approach: JSONB for layout metadata (fast reads) + Storage Buckets for heavy binaries.

Tables

profiles: Public user info (username, avatar_url). Linked to auth.users.

friendships: Links two users.

user_a (uuid), user_b (uuid). Constraint: user_a < user_b to prevent duplicates.

books: Created automatically when friendship is accepted.

friendship_id (FK), cover_url.

pages (The core entity):

book_id (FK).

type: 'letter' (sent, immutable) or 'memory' (collaborative).

content_json: JSONB. Stores the coordinate data of items (photos, text).

drawing_path: Text. Path to the .data file in Supabase Storage (PencilKit binary).

Storage Buckets

memories-assets: Public bucket.

Path: drawings/{page_id}.data

Path: images/{page_id}/{item_id}.jpg

5. The "Virtual Canvas" System

To solve iPhone vs iPad aspect ratios, we use a Fixed Coordinate System.

Virtual Size: 1000pt x 1400pt (Constant).

Logic: All coordinates saved in the DB are relative to this 1000x1400 grid.

Rendering: The View scales the canvas container using CGAffineTransform to fit the current device screen, but the internal drawing logic remains consistent.

6. Folder Structure

Memories/
├── App/                  # Entry points (MemoriesApp.swift)
├── Controllers/          # UIKit ViewControllers (Logic-heavy UI)
├── Models/               # Codable structs (CanvasModels.swift)
├── Services/             # Singletons (SupabaseManager, AuthService)
├── Utils/                # Helpers (Crypto, Extensions)
├── ViewModels/           # Business Logic (EditorViewModel, LoginViewModel)
├── Views/                # Reusable UI Components (CanvasElementView, RootView)
└── Secrets.swift         # API Keys (GitIgnored)


7. Roadmap & Future Features

Phase 1: Foundation (Current)

[x] Apple Sign In (Supabase Auth).

[x] Canvas Editor (PencilKit + Image dragging).

[x] JSON Serialization of Canvas data.

[ ] Connect Editor to real Supabase Storage/DB (Upload logic).

Phase 2: Social Graph

[ ] User Search (By username).

[ ] Friend Request System.

[ ] Automatic Book Creation on friendship acceptance.

Phase 3: The Book Viewer

[ ] Book List View (Grid of covers).

[ ] UIPageViewController implementation for realistic page turning.

[ ] Fetching pages from DB and rendering them via CanvasElementView (Read-only mode).

Phase 4: UI Overhaul

[ ] Complete redesign of the interface.

[ ] Note: Since logic is in ViewModels, this phase should only affect Controllers and Views.

8. Important Notes for Agent

Secrets: Never output API keys in code snippets. Refer to Secrets.supabaseUrl.

Context: We are currently simulating the DB save in console. Next steps involve writing the actual network calls in EditorViewModel.
