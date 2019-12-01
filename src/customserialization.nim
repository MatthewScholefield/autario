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
      let content = s.next().scalarContent
      case content:
        of "null":
          result = JsonNodeObj(kind: JNull)
        of "true":
          result = JsonNodeObj(kind: JBool, bval: true)
        of "false":
          result = JsonNodeObj(kind: JBool, bval: false)
        else:
          if "." in content:
            try:
              result = JsonNodeObj(kind: JFloat, fnum: content.parseFloat)
            except ValueError:
              raise newException(YamlConstructionError, "Invalid float")
          else:
            try:
              result = JsonNodeObj(kind: JInt, num: content.parseInt)
            except ValueError:
              raise newException(YamlConstructionError, "Invalid integer")
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
