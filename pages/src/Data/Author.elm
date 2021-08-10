module Data.Author exposing (Author, all, decoder, greg, jack, redDoor)

import Cloudinary
import Json.Decode as Decode exposing (Decoder)
import List.Extra
import Pages.Url exposing (Url)


type alias Author =
    { name : String
    , avatar : Url
    , bio : String
    }


all : List Author
all =
    [ greg
    , jack
    ]


greg : Author
greg =
    { name = "Greg Ziegan"
    , avatar = Cloudinary.url "v1602899672/reddoorcollective/greg-profile.jpg" Nothing 140
    , bio = "Organizer in Red Door Collective. Website guy."
    }


jack : Author
jack =
    { name = "Jack Marr"
    , avatar = Cloudinary.url "v1602899672/reddoorcollective/jack-profile.jpg" Nothing 140
    , bio = "Organizer in Red Door Collective. Data expert."
    }


redDoor : Author
redDoor =
    { name = "Red Door Collective"
    , avatar = Cloudinary.url "v2344343/reddoorcollective/red-door-avatar.jpg" Nothing 140
    , bio = "A grassroots groups helping tenants to organize for dignified housing."
    }


decoder : Decoder Author
decoder =
    Decode.string
        |> Decode.andThen
            (\lookupName ->
                case List.Extra.find (\currentAuthor -> currentAuthor.name == lookupName) all of
                    Just author ->
                        Decode.succeed author

                    Nothing ->
                        Decode.fail ("Couldn't find author with name " ++ lookupName ++ ". Options are " ++ String.join ", " (List.map .name all))
            )
