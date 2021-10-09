module Data.Author exposing (Author, greg, jack, redDoor)

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


redDoor : Author
redDoor =
    { name = "Red Door Collective"
    , avatar = Cloudinary.urlSquare "avatars/red-door-logo.png" Nothing 140
    , bio = "A grassroots groups helping tenants to organize for dignified housing."
    }
