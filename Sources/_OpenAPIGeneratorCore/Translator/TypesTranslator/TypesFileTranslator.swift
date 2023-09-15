//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftOpenAPIGenerator open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftOpenAPIGenerator project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftOpenAPIGenerator project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import OpenAPIKit

/// A translator for the generated common types.
///
/// Types.swift is the Swift file containing all the reusable types from
/// the "Components" section in the OpenAPI document, as well as all of the
/// namespaces for each OpenAPI operation, including their Input and Output
/// types.
///
/// Types generated in this file are depended on by both Client.swift and
/// Server.swift.
struct TypesFileTranslator: FileTranslator {

  var config: Config
  var diagnostics: any DiagnosticCollector
  var components: OpenAPI.Components

  func translateFile(
    parsedOpenAPI: ParsedOpenAPIRepresentation
  ) throws -> [StructuredSwiftRepresentation] {

    let doc = parsedOpenAPI

    let topComment: Comment = .inline(Constants.File.topComment)

    let imports =
    Constants.File.imports
    + config.additionalImports
      .map { ImportDescription(moduleName: $0) }

    let components = try translateComponents(doc.components)

    func blocks(leadingName: String) -> [StructuredSwiftRepresentation] {
      var i = 0
      return structCodeBlocks(block: components).map { block in
        let typesFile = FileDescription(
          topComment: topComment,
          imports: imports,
          codeBlocks: [block.block]
        )

        i =  i + 1
        return StructuredSwiftRepresentation(
          file: .init(
            name: leadingName + block.name + ".swift",
            contents: typesFile
          )
        )
      }
    }

    if let namespace = config.namespace {
      // we should make a top level file for this name space
      let typesFile = FileDescription(
        isNamespace: true,
        topComment: topComment,
        imports: [],
        codeBlocks: [CodeBlock(item: CodeBlockItem.declaration(.enum(.init(accessModifier: .public, name: namespace))))]
      )

      return [StructuredSwiftRepresentation(
        file: .init(
          name: namespace + ".swift",
          contents: typesFile
        )
      )] + blocks(leadingName: namespace + "_")
    }

    return blocks(leadingName: "")
  }
}

struct Code {
  var name: String
  var block: CodeBlock
}

func structCodeBlocks(block: CodeBlock) -> [Code] {
  switch block.item {
  case .declaration(let d):
    return codeBlocks(decleration: d)
  case .expression(let e):
    return []
  }
}

func codeBlocks(decleration: Declaration) -> [Code] {
  var blocks: [Code] = []

  switch decleration {
  case .struct(let d):
    blocks.append(Code(name: d.name, block: CodeBlock(item: CodeBlockItem.declaration(decleration))))
  case .enum(let e):
    if e.members.contains(where: {
      switch $0 {
      case .enumCase:
        return true
      default:
        break
      }

      return false
    }) {
      blocks.append(Code(name: e.name, block: CodeBlock(item: CodeBlockItem.declaration(decleration))))
    } else {
      e.members.forEach { enumDec in
        blocks.append(contentsOf: codeBlocks(decleration: enumDec))
      }
    }
  case .protocol(let p):
    blocks.append(Code(name: p.name, block: CodeBlock(item: CodeBlockItem.declaration(decleration))))
  case .commentable(_, let d):
    blocks.append(contentsOf: codeBlocks(decleration: d))
  case .deprecated(_, let d):
    blocks.append(contentsOf: codeBlocks(decleration: d))
  default:
    break
  }

  return blocks
}
