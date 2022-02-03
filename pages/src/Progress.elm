module Progress exposing (Tracking)


type alias Tracking =
    { current : Int
    , total : Int
    , errored : Int
    }
