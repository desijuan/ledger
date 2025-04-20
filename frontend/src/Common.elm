port module Common exposing
    ( Group
    , GroupOverviewApiResponse
    , Member
    , Tr
    , decodeGroupOverviewApiResponse
    , groupOverviewApiResponseDecoder
    , httpErrorToString
    , logToConsole
    )

import Array exposing (Array)
import Http
import Json.Decode exposing (Decoder, bool, int, list, string, succeed)
import Json.Decode.Pipeline exposing (required)


port logToConsole : String -> Cmd msg


type alias Group =
    { id : String, name : String, description : String, members : Array Member }


type alias Member =
    { id : Int, name : String }


type alias Tr =
    { id : Int, from_id : Int, to_id : Int, amount : Int, description : String, timestamp : String }


httpErrorToString : Http.Error -> String
httpErrorToString error =
    case error of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus statusCode ->
            "Bad status: " ++ String.fromInt statusCode

        Http.BadBody message ->
            "Bad body: " ++ message


type alias GroupOverviewApiResponse =
    { success : Bool
    , groupBoard : GroupBoard
    }


type alias GroupBoard =
    { groupId : String
    , name : String
    , description : String
    , createdAt : String
    , members : List Member
    , trs : List Tr
    }


groupOverviewApiResponseDecoder : Decoder GroupOverviewApiResponse
groupOverviewApiResponseDecoder =
    succeed GroupOverviewApiResponse
        |> required "success" bool
        |> required "group_board" groupBoardDecoder


groupBoardDecoder : Decoder GroupBoard
groupBoardDecoder =
    succeed GroupBoard
        |> required "group_id" string
        |> required "name" string
        |> required "description" string
        |> required "created_at" string
        |> required "members" (list memberDecoder)
        |> required "trs" (list transactionDecoder)


memberDecoder : Decoder Member
memberDecoder =
    succeed Member
        |> required "member_id" int
        |> required "name" string


transactionDecoder : Decoder Tr
transactionDecoder =
    succeed Tr
        |> required "tr_id" int
        |> required "from_id" int
        |> required "to_id" int
        |> required "amount" int
        |> required "description" string
        |> required "timestamp" string


decodeGroupOverviewApiResponse : String -> Result Json.Decode.Error GroupOverviewApiResponse
decodeGroupOverviewApiResponse jsonString =
    Json.Decode.decodeString groupOverviewApiResponseDecoder jsonString
