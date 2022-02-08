module Data.Author exposing (Author, greg, jack, kathryn, redDoor)

import Cloudinary
import Pages.Url exposing (Url)


type alias Author =
    { name : String
    , avatar : Url
    , bio : String
    }


greg : Author
greg =
    { name = "Greg Ziegan"
    , avatar = Cloudinary.urlSquare "avatars/greg-profile.jpg" Nothing 140
    , bio = "Organizer in Red Door Collective. Website guy."
    }


jack : Author
jack =
    { name = "Jack Marr"
    , avatar = Cloudinary.urlSquare "avatars/jack-avatar.jpg" Nothing 140
    , bio = "Organizer in Red Door Collective. Data expert."
    }


kathryn : Author
kathryn =
    { name = "Kathryn Brown"
    , avatar = Cloudinary.urlSquare "avatars/kathryn-avatar.jpg" Nothing 140
    , bio = "Organizer in Red Door Collective. Public health correspondent."
    }


redDoor : Author
redDoor =
    { name = "Red Door Collective"
    , avatar = Cloudinary.urlSquare "avatars/red-door-logo.png" Nothing 140
    , bio = "A grassroots groups helping tenants to organize for dignified housing."
    }
