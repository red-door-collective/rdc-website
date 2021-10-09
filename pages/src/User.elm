module User exposing (Permissions(..), Role, User)


type Permissions
    = Superuser


type alias Role =
    { id : Int
    , name : String
    , description : Maybe String
    }


type alias User =
    { id : Int
    , firstName : String
    , lastName : String
    , name : String
    , roles : List Role
    }
