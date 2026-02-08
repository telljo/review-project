// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "trix"
import "@rails/actiontext"
import "@rails/request.js"
import "./controllers"

// Import Font Awesome
import { library, dom } from '@fortawesome/fontawesome-svg-core'
import {
  faStar,
  faSearch,
  faSpinner,
  faBookOpen,
  faStarHalfAlt
} from '@fortawesome/free-solid-svg-icons'
import {
  faStar as farStar
} from '@fortawesome/free-regular-svg-icons'

// Add Font Awesome icons to the library
library.add(faStar, faStarHalfAlt, farStar, faSearch, faSpinner, faBookOpen)


// Initialize Font Awesome
dom.watch()



