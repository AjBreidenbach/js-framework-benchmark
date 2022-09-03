import std/[asyncdispatch, random, strformat, json, strutils]
import anamorphic/html
import anamorphic/anamorph
import anamorphic/context

var app = newAnamorph("App")

const ADJECTIVES = ["pretty", "large", "big", "small", "tall", "short", "long", "handsome", "plain", "quaint", "clean", "elegant", "easy", "angry", "crazy", "helpful", "mushy", "odd", "unsightly", "adorable", "important", "inexpensive", "cheap", "expensive", "fancy"]
const COLORS = ["red", "yellow", "blue", "green", "pink", "brown", "purple", "brown", "white", "black", "orange"]
const NOUNS = ["table", "chair", "house", "bbq", "desk", "car", "pony", "cookie", "sandwich", "burger", "pizza", "mouse", "keyboard"]

proc randomAdjective: string = ADJECTIVES[rand(ADJECTIVES.high)]
proc randomColor: string = COLORS[rand(COLORS.high)]
proc randomNoun: string = NOUNS[rand(NOUNS.high)]


var tableRow = newAnamorph("Row")
tableRow.setup do(context: Context):

  let onSelect = context.registerClickHandler() do(e: ClickEventPayload):
    context.emit("select", context.attributes["n"].str)

  let onRemove = context.registerClickHandler() do(e: ClickEventPayload):
    context.emit("remove", context.attributes["n"].str)
  
  context.render do -> HtmlNode:
    let n = context.attributes["n"].str
    let label = context.attributes["label"].str
    let selected = (
      try: context.attributes["selected"].str == "true"
      except: false
    )

    result = tr(
      td( {"class": "col-md-1"}, $n ),
      td(
        {"class": "col-md-4"},
        a( {"class": "lbl"}, label )
      ).withHandlers(onSelect),
      td(
        {"class": "col-md-1"},
        a(
          {"class": "remove"},
          span( {"class": "remove glyphicon glyphicon-remove", "aria-hidden": "true"} )
        ).withHandlers(onRemove)
      ),
      td({"class": "col-md-6"})
    ).key($n)

    if selected:
      echo "selected", n, label
      result.addClass("danger")


app.setup do(context: Context):
  var rows: seq[HtmlNode]
  var data: seq[(int, string)]
  var selected: int = -1

  var startingId = 1
  proc append(n=1000) =
    for i in 0..<n:
      let label = &"{randomAdjective()} {randomColor()} {randomNoun()}"
      let id = startingId + i
      data.add((id, label))
      rows.add tableRow.h(context, {"n": $(id), "label": label})
    startingId += n

    context.requestRender

  proc clear =
    rows.setLen(0)
    data.setLen(0)

  context.on("create1k") do():
    clear()
    append(1000)

  context.on("create10k") do():
    clear()
    append(10000)
  
  context.on("clear") do():
    clear()
    context.requestRender

  context.on("append1k") do():
    append(1000)

  context.on("swapRows") do():
    if rows.len > 998:
      swap(rows[1], rows[998])

      context.requestRender

  context.on("update10th") do():
    for i in 0..rows.high:
      if i mod 10 == 0:
        let label = &"{data[i][1]} !!!"
        data[i][1] = label
        rows[i] = tableRow.h(context, {"n": $(data[i][0]), "label": label})
    context.requestRender

  context.on("remove") do(id: string):
    if id == $selected: selected = -1

    let idAsInt = parseInt(id)

    for i in 0..data.high:
      if idAsInt == data[i][0]:
        data.delete(i)
        #rows[i] = nil
        rows.delete(i)

        break

    context.requestRender

  context.on("select") do(id: string):
    let idAsInt = parseInt(id)
    if id == $selected: return
    var newSelected = -1
    for i in 0..data.high:
      let itemId = data[i][0]
      if itemId == selected:
        rows[i] = tableRow.h(context, {"n": $itemId, "label": data[i][1]})
      elif itemId == idAsInt:
        rows[i] = tableRow.h(context, {"n": $itemId, "label": data[i][1], "selected": "true"})
        newSelected = itemId
    selected = newSelected

    context.requestRender



  context.render do -> HtmlNode:
    table(
      {"class": "table table-hover table-striped test-data"},
      tbody(
        {"id": "tbody"},
        keyed(rows)
      )
    )

var controls = newAnamorph("Controls")

proc controlsCell(buttonId, buttonText: string, handler: EventHandler): HtmlNode =
  tdiv(
    {"class": "col-sm-6 smallpad"},
    button(
      {"type": "button", "class": "btn btn-primary btn-block", "id": buttonId},
      buttonText
    ).withHandlers(handler)
  )

controls.setup do(context: Context):
  let create1k = context.registerClickHandler do(e: ClickEventPayload):
    context.emit("create1k")

  let create10k = context.registerClickHandler do(e: ClickEventPayload):
    context.emit("create10k")

  let append1k = context.registerClickHandler do(e: ClickEventPayload):
    context.emit("append1k")

  let update10th = context.registerClickHandler do(e: ClickEventPayload):
    context.emit("update10th")

  let handleClear = context.registerClickHandler do (e: ClickEventPayload):
    context.emit("clear")

  let swapRows = context.registerClickHandler do(e: ClickEventPayload):
    context.emit("swapRows")

  context.render do -> HtmlNode:
    tdiv(
      {"class": "row"},
      controlsCell("run", "Create 1,000 rows", create1k),
      controlsCell("runlots", "Create 10,000 rows", create10k),
      controlsCell("add", "Append 1,000 rows", append1k),
      controlsCell("update", "Update every 10th row", update10th),
      controlsCell("clear", "Clear", handleClear),
      controlsCell("swaprows", "Swap Rows", swaprows),
    )

app.registerComponent(controls)
app.registerComponent(tableRow)
app.useCompression

app.serve(Port(9001))
