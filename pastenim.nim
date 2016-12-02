# pastenim: a simple pastebin using Nim and Jester

# Written by Adam Chesak
# Released under the MIT open source license.


import jester
import shorturl
import asyncdispatch
import json
import htmlgen
import strutils
import times
import os


const
    PASTE_PORT = 80
    PATH_BASE = "http://localhost:" & $PASTE_PORT & "/"
    PATH_PASTES : string = "pastes/"
    PATH_LIST : string = "pasteList"
    LIST_MAX : int = 10
    PATH_HTML_NEW = "html/newpaste.html"
    PATH_HTML_VIEW = "html/viewpaste.html"
    PATH_HTML_SUBMIT = "html/submitpaste.html"
    PATH_HTML_LIST = "html/listpastes.html"


proc generatePasteID(): string =
    ## Generates and returns a paste ID from the current timestamp.

    var currentTime : int = int(getTime())
    return encodeURLSimple(currentTime)


proc getPaste(pasteKey : string): string =
    ## Reads the paste from the given ``pasteKey``.

    # Verify that the file exists.
    if not existsFile(PATH_PASTES & pasteKey):
        return nil

    var pasteData : string = readFile(PATH_PASTES & pasteKey)
    return pasteData


proc getPasteList(number : int): seq[string] =
    ## Gets the list of submitted pastes, up to the given ``number``.

    if not existsFile(PATH_LIST):
        writeFile(PATH_LIST, "")

    var lastPastes : string = readFile(PATH_LIST)
    var lastLines : seq[string] = lastPastes.splitLines()

    if number >= len(lastLines) or number <= 0:
        return lastLines

    return lastLines[0..number - 1]


proc submitPaste(title : string, data : string): string =
    ## Saves a paste with the given ``title`` and ``data``. Returns the generated paste ID.

    if not existsDir(PATH_PASTES):
        createDir(PATH_PASTES)

    var cleanedTitle : string = title.splitLines().join("")

    var pasteID : string = generatePasteID()
    while existsFile(PATH_PASTES & pasteID):
        pasteID = generatePasteID()

    var savedData : string = cleanedTitle & "\n" & data
    writeFile(PATH_PASTES & pasteID, savedData)
    if not existsFile(PATH_LIST):
        writeFile(PATH_LIST, "")
    writeFile(PATH_LIST, pasteID & "\n" & readFile(PATH_LIST))

    return pasteID


proc showNewForm(blankField : bool = false): string = 
    ## Shows the new paste submission form.

    var newForm : string = readFile(PATH_HTML_NEW)
    if blankField:
        newForm = newForm.replace("{BLANKFIELDERROR}", "block")
    else:
        newForm = newForm.replace("{BLANKFIELDERROR}", "none")
    return newForm


proc showPaste(pasteID : string): string = 
    ## Shows an existing paste.

    var pasteData : string = getPaste(pasteID)
    if pasteData == nil:
        return nil
    var splitIndex : int = pasteData.find("\n")
    var title : string = pasteData[0..splitIndex]
    var data : string = pasteData[splitIndex..high(pasteData)]
    return readFile(PATH_HTML_VIEW).replace("{TITLE}", title).replace("{DATA}", data)


proc showPasteList(number : int = LIST_MAX): string = 
    ## Shows a list of the most recent pastes.

    var lines : seq[string] = getPasteList(number)
    var output : string = ""
    var count : int = 0
    for line in lines:
        if line.strip() == "":
            continue
        var path : string = PATH_BASE & PATH_PASTES & line
        output &= "<li><a href=\"{URL}\">{URL}</a></li>".replace("{URL}", path)
        count += 1
    return readFile(PATH_HTML_LIST).replace("{PASTELIST}", output).replace("{COUNT}", $count)


proc showSubmit(title : string, data : string): string = 
    ## Submits a paste and shows a link to it.

    var pasteID : string = submitPaste(title, data)
    return readFile(PATH_HTML_SUBMIT).replace("{LINK}", PATH_BASE & PATH_PASTES & pasteID)


settings:
    port = Port(PASTE_PORT)


routes:

    # Display submission form:
    get "/":
        resp showNewForm()


    # Display a specific paste:
    get "/pastes/@pasteID":
        var pasteData : string = showPaste(@"pasteID")
        if pasteData != nil:
            resp pasteData


    # Display list of previous pastes:
    get "/list":
        resp showPasteList()


    # Display list of previous pastes:
    get "/list/@number?":
        var number : int = LIST_MAX
        if @"number" != "":
            number = parseInt(@"number")
        if number < 1:
            number = LIST_MAX

        resp showPasteList(number)


    # Submit a paste:
    post "/submit":
        if (@"title").strip() == "" or (@"text").strip() == "":
            resp showNewForm(blankField = true)
        else:
            resp showSubmit(@"title", @"text")


runForever()
