import json
import collections/tables
import yaml/serialization, yaml/taglib, yaml/presenter
import strutils
import system


proc ensureKind(s: var YamlStream, kind: YamlStreamEventKind) =
  var event = s.next()
  if event.kind != kind:
    raise newException(YamlConstructionError, "Expected " & $kind & " got " & $event.kind)


proc constructObject*(s: var YamlStream, c: ConstructionContext,
    result: var JsonNodeObj) =
  case s.peek().kind:
    of yamlScalar:
      var ev = s.next()
      let content = ev.scalarContent
      case content:
        of "null":
          result = JsonNodeObj(kind: JNull)
        of "true":
          result = JsonNodeObj(kind: JBool, bval: true)
        of "false":
          result = JsonNodeObj(kind: JBool, bval: false)
        else:
          try:
            if "." in content:
              result = JsonNodeObj(kind: JFloat, fnum: content.parseFloat)
            else:
              result = JsonNodeObj(kind: JInt, num: content.parseInt)
          except ValueError:
            result = JsonNodeObj(kind: JString, str: content)
    of yamlStartSeq:
      s.ensureKind(yamlStartSeq)
      result = JsonNodeObj(kind: JArray, elems: @[])
      while s.peek().kind != yamlEndSeq:
        var child = new(JsonNode)
        constructObject(s, c, child[])
        result.elems.add(child)
      s.ensureKind(yamlEndSeq)
    of yamlStartMap:
      s.ensureKind(yamlStartMap)
      result = newJObject()[]
      while s.peek().kind != yamlEndMap:
        var key: string
        constructObject(s, c, key)
        var value = new(JsonNode)
        constructObject(s, c, value[])
        result.fields[key] = value
      s.ensureKind(yamlEndMap)
    else:
      raise newException(YamlConstructionError, "Invalid yaml event for JSON object")


proc representObject*(node: JsonNodeObj, ts: TagStyle,
    c: SerializationContext, tag: TagId) =
  let ts = if ts == tsRootOnly: tsNone else: ts
  case node.kind:
    of JInt:
      c.put(scalarEvent($node.num))
    of JFloat:
      c.put(scalarEvent($node.fnum))
    of JBool:
      c.put(scalarEvent($node.bval))
    of JString:
      representObject(node.str, ts, c, tag)
    of JNull:
      c.put(scalarEvent("null"))
    of JObject:
      c.put(startMapEvent(tag))
      for key, val in node.fields.pairs:
        representChild($key, ts, c)
        representObject(val[], ts, c, tag)
      c.put(endMapEvent())
    of JArray:
      c.put(startSeqEvent(tag))
      for val in node.elems:
        representObject(val[], ts, c, tag)
      c.put(endSeqEvent())



when defined unit_tests:
  proc checkSerialization(obj: JsonNode) =
    var obj2: JsonNode
    load(dump(obj), obj2)
    assert($obj == $obj2)

  checkSerialization(%*{"createdAt": 12})
  checkSerialization(%*{"createdAt": {"innerVal": 12}})
  checkSerialization(%*{"createdAt": {"innerVal": "string"}})
