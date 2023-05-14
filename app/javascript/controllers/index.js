// This file is auto-generated by ./bin/rails stimulus:manifest:update
// Run that command whenever you add a new controller or create them with
// ./bin/rails generate stimulus controllerName

import { application } from "./application"

import BookController from "./book_controller"
application.register("book", BookController)

import BooksController from "./books_controller"
application.register("books", BooksController)

import BookSelectController from "./book_select_controller"
application.register("book_select", BookSelectController)

import RemovalsController from "./removals_controller"
application.register("removals", RemovalsController)

import ReviewController from "./review_controller"
application.register("review", ReviewController)

import SearchController from "./search_controller"
application.register("search", SearchController)

import DropdownController from "./dropdown_controller"
application.register("dropdown", DropdownController)


