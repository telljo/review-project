---
version: 1
slug: "app-views-books-show-html-erb"
primary_target: "app/views/books/show.html.erb"
related_targets: ["app/views/books/_collection_actions.html.erb","app/views/book_selections","app/views/devise","app/controllers/book_selections_controller.rb"]
---

# Book detail to shelf

Mode: Operate. Extend the existing book page and authentication handoff for individual readers. Preserve search, public shelves, review editing, and the established visual system. The owner confirmed inline shelf choice, return to the book after saving, and recoverable failures. Password reset is excluded after the owner asked to skip it if mail is not configured; repository and local environment checks found no delivery configuration.

## Direction contract

THESIS: Keep the exact book in view from discovery through saving. Put the shelf action before the description instead of making a reader finish the synopsis to act.

OWN-WORLD: Inherit Bookshelf's dark slate surfaces, Lato typography, pale blue focus/selection accents, existing buttons, and real covers. Use native radios and disclosures with calm spacing; no new imagery or visual identity.

STORY: Identify the book, save or authenticate with its title visible, choose a shelf, and remain on the same book with its saved state and a link to that shelf. Validation, expired sessions, and network failures retain context; cancel returns to the originating book.

FIRST VIEWPORT: Desktop has the cover beside title, author, rating, and shelf controls. Phone uses a small cover beside the title and a full-width action area below. Description follows the action, with a concise preview and disclosure for long text. The signature interaction is shelf choice becoming durable saved-state feedback in the same reading position.

FORM: Local extension of the incumbent detail page; precisely confirmed interaction and composition, so no concept-seed round. Code-led. Preserve the existing search-origin selection route. Use exact database book IDs for detail-origin saves, and never infer a different edition from missing ISBN metadata.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Implemented outcome

The detail-origin save path preserves the existing database book ID through signup/login and returns to the same book for inline shelf choice. Initial saves are idempotent; changing an existing shelf requires the explicit Change shelf / Update shelf path. Saved status, View my shelf, long-description disclosure, and recoverable errors remain on the book surface. The existing search-origin ISBN selection path remains separate. ISBN is required by the current database schema; no schema change or missing-ISBN persistence behavior was introduced.

The final login correction keeps Remember me and its native checkbox inside one associated label, with an 8px gap and 44px minimum target. The finish verdict records that correction as resolved. Password reset remains excluded under the owner's instruction to skip it when mail is unconfigured.

Documentation disposition: this is an ordinary extension of the incumbent dark slate/Lato system. `DESIGN.md` and `.impeccable/design.json` were already absent; no new visual world or global system change was approved. The FINISH documentation obligation is satisfied by the source/capture comparison and scope record in `.impeccable/implementation/book-to-shelf-review/documentation-review.md`, without inventing a global token system. No new shipping raster assets were introduced.
