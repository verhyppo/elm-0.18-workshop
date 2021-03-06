module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (class, defaultValue, href, property, target)
import Html.Events exposing (..)
import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (..)
import Parser exposing ((|.), (|=), Parser, end, ignore, keep, oneOrMore, repeat, symbol, zeroOrMore)
import SampleResponse


type SearchTerm
    = Include String
    | Exclude String


isSpace : Char -> Bool
isSpace char =
    char == ' '


excludeTerm : Parser SearchTerm
excludeTerm =
    Parser.succeed Exclude
        |. ignore zeroOrMore isSpace
        |. symbol "-"
        |= keep oneOrMore (\char -> char /= ' ')


includeTerm : Parser SearchTerm
includeTerm =
    Parser.succeed Include
        |. ignore zeroOrMore isSpace
        |= keep oneOrMore (\char -> char /= ' ')


searchTerm : Parser SearchTerm
searchTerm =
    Parser.oneOf
        [ excludeTerm
        , includeTerm
        ]


searchTerms : Parser (List SearchTerm)
searchTerms =
    repeat zeroOrMore searchTerm
        |. ignore zeroOrMore isSpace
        |. end


spaces : Parser ()
spaces =
    ignore zeroOrMore (\c -> c == ' ')


main : Program Never Model Msg
main =
    Html.beginnerProgram
        { view = view
        , update = update
        , model = initialModel
        }


searchResultDecoder : Decoder SearchResult
searchResultDecoder =
    -- See https://developer.github.com/v3/search/#example
    -- and http://package.elm-lang.org/packages/NoRedInk/elm-decode-pipeline/latest
    --
    -- Look in SampleResponse.elm to see the exact JSON we'll be decoding!
    --
    -- TODO replace these calls to `hardcoded` with calls to `required`
    Json.Decode.succeed SearchResult
        |> hardcoded 0
        |> hardcoded ""
        |> hardcoded 0


type alias Model =
    { query : String
    , results : List SearchResult
    , terms : List SearchTerm
    }


type alias SearchResult =
    { id : Int
    , name : String
    , stars : Int
    }


initialModel : Model
initialModel =
    { query = "tutorial"
    , results = decodeResults SampleResponse.json
    , terms = termsFromQuery "tutorial"
    }


responseDecoder : Decoder (List SearchResult)
responseDecoder =
    decode identity
        |> required "items" (list searchResultDecoder)


decodeResults : String -> List SearchResult
decodeResults json =
    case decodeString responseDecoder json of
        -- TODO add branches to this case-expression which return:
        --
        -- * the search results, if decoding succeeded
        -- * an empty list if decoding failed
        --
        -- see http://package.elm-lang.org/packages/elm-lang/core/4.0.0/Json-Decode#decodeString
        --
        -- HINT: decodeString returns a Result which is one of the following:
        --
        -- Ok (List SearchResult)
        -- Err String
        _ ->
            []


view : Model -> Html Msg
view model =
    div [ class "content" ]
        [ header []
            [ h1 [] [ text "ElmHub" ]
            , span [ class "tagline" ] [ text "Like GitHub, but for Elm things." ]
            ]
        , input [ class "search-query", onInput SetQuery, defaultValue model.query ] []
        , button [ class "search-button", onClick Search ] [ text "Search" ]
        , div []
            [ span [ class "search-terms" ] [ text "Showing results for:" ]
            , span [] (List.map viewSearchTerm model.terms)
            ]
        , ul [ class "results" ]
            (List.map viewSearchResult model.results)
        ]


viewSearchTerm : SearchTerm -> Html Msg
viewSearchTerm term =
    case term of
        Include str ->
            span [ class "search-term included" ] [ text str ]

        Exclude str ->
            span [ class "search-term excluded" ] [ text str ]


viewSearchResult : SearchResult -> Html Msg
viewSearchResult result =
    li []
        [ span [ class "star-count" ] [ text (toString result.stars) ]
        , a [ href ("https://github.com/" ++ result.name), target "_blank" ]
            [ text result.name ]
        , button [ class "hide-result", onClick (DeleteById result.id) ]
            [ text "X" ]
        ]


type Msg
    = SetQuery String
    | DeleteById Int
    | Search


termsFromQuery : String -> List SearchTerm
termsFromQuery query =
    case Parser.run searchTerms query of
        Ok validTerms ->
            validTerms

        Err invalidTerms ->
            []


update : Msg -> Model -> Model
update msg model =
    case msg of
        SetQuery query ->
            { model | query = query }

        DeleteById idToHide ->
            let
                newResults =
                    List.filter (\{ id } -> id /= idToHide) model.results
            in
            { model | results = newResults }

        Search ->
            { model | terms = termsFromQuery model.query }
