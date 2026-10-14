# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Bookshelf is a public reading tracker for individual readers. Its primary job is
to help readers keep a record of their books, reading status, ratings, and
reviews that other people can browse.

The audience and public reading-tracker focus were confirmed by the owner during
initialization. Specific reader segments, usage frequency, and primary devices
remain open.

## Product Purpose

Help individual readers collect books, track their reading, and record their
thoughts. The existing workflow is to find a book, save it to a shelf, update its
reading status, and add a rating and review.

The owner's priority is excellent usability: these tasks should be easy to
understand and complete, and a reader's record should be easy to return to.

## Positioning

A public reading tracker centered on each individual's shelves and reviews.

Open: no distinct competitive claim or differentiating mechanism has been
confirmed. Do not invent claims about advantages over other reading products.

## Operating Context

The current web interface supports discovery through book search and browsing
existing books and reviews. Signed-in readers maintain their collections and
reviews. Visitors can browse username-based public profiles, shelves, and
reviews.

Reading status uses three shelves: **Read**, **Reading**, and **Want to read**.
Owners can move books between shelves using collection controls or drag and drop.

These workflows are evidenced by the existing implementation; they are not an
approved roadmap for additional social features.

## Capabilities and Constraints

Current implemented capabilities:

- Search Google Books by title, author, or ISBN and save results to a collection.
- Track a book on one of the three reading-status shelves.
- Browse book details, public collections, and reviews.
- Write rich-text reviews and star ratings; edit and delete reviews.
- Create accounts and access username-based public profiles.

The existing application uses Rails, Hotwire/Turbo, Stimulus, and SCSS, with
PostgreSQL and Redis. Google Books provides search metadata and cover images;
availability and completeness depend on that external source. Rich-text file
and image attachments are explicitly disabled.

Open: privacy options, commercial model, new social capabilities, and any
product-specific accessibility standard have not been decided in this session.
The presence of a capability in the code does not establish a new promise or
permission to change its behavior.

## Brand Commitments

The existing product name is **Bookshelf**, with a logo at
`app/assets/images/logo.svg`.

The owner explicitly prioritizes "Excellent usability and a simple clean design
that doesn't look like it is AI created." Preserve that commitment in future
work. No new palette, typeface, visual reference, or brand voice was selected
during initialization.

## Evidence on Hand

- `README.md`: product description, runtime requirements, and local setup.
- `config/routes.rb`, `app/models/`, and `app/controllers/`: current capabilities,
  reading statuses, public routes, and account-dependent operations.
- `app/views/`: real interface copy and implemented workflows.
- `app/assets/images/`: existing logo, shelf artwork, avatar, and cover fallback.
- `app/assets/stylesheets/`: the incumbent visual implementation.
- `spec/requests/`: request tests for books, search, and sessions.

The owner confirmed the audience, usability priority, design commitment, and
workflow preference during initialization on 2026-10-15. No user research,
testimonials, customer counts, performance benchmarks, or competitive evidence
was supplied or verified. Future work must use real evidence for such claims.

## Product Principles

1. Make the reader's core tasks easy to understand and complete.
2. Keep the product simple; new complexity needs a clear benefit for the reader.
3. Keep individual reading records central to product decisions.
4. Make deliberate design choices that honor the owner's request for a simple,
   clean interface that does not look AI created.
