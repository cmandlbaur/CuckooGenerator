//
//  Generator_r1.swift
//  CuckooGenerator
//
//  Created by Tadeas Kriz on 13/01/16.
//  Copyright © 2016 Brightify. All rights reserved.
//

struct Generator_r1: Generator {

    static func generateWithIndentation(indentation: String, token: Token) -> [String] {
        var output: [String] = []
        
        switch token {
        case let containerToken as ContainerToken:
            output += generateMockingClass(containerToken)
    
        case let method as Method:
            output += generateMockingMethod(method)
            
        default:
            break
            
        }
        
        return output.map { "\(indentation)\($0)" }
    }
    
    private static func generateMockingClass(token: ContainerToken) -> [String] {
        let name = token.name
        let accessibility = token.accessibility
        let implementation = token.implementation
        let children = token.children
        
        guard accessibility != .Private else { return [] }
        
        var output: [String] = []
        output += ""
        output += "\(accessibility.sourceName) class \(mockClassName(name)): \(name), Cuckoo.Mock {"
        output += "    \(accessibility.sourceName) let manager: Cuckoo.MockManager<\(stubbingProxyName(name)), \(verificationProxyName(name))> = Cuckoo.MockManager()"
        output += ""
        output += "    private let observed: \(name)?"
        output += ""
        output += "    \(accessibility.sourceName) required\(implementation ? " override" : "") init() {"
        output += "        observed = nil"
        output += "    }"
        output += ""
        output += "    \(accessibility.sourceName) required init(spyOn victim: \(name)) {"
        output += "        observed = victim"
        output += "    }"
        output += generateWithIndentation("    ", tokens: children)
        output += ""
        output += generateStubbingWithIndentation("    ", token: token)
        output += ""
        output += generateVerificationWithIndentation("    ", token: token)
        output += "}"
        return output
    }
    
    private static func generateMockingMethod(token: Method) -> [String] {
        let name = token.name
        let accessibility = token.accessibility
        let returnSignature = token.returnSignature
        let isOverriding = token is ClassMethod
        let parameters = token.parameters
        
        guard accessibility != .Private else { return [] }
        var output: [String] = []
        let rawName = name.takeUntilStringOccurs("(") ?? ""
        
        let fullyQualifiedName = fullyQualifiedMethodName(name, parameters: parameters, returnSignature: returnSignature)
        let parametersSignature = methodParametersSignature(parameters)
        
        var managerCall: String
        let tryIfThrowing: String
        if returnSignature.containsString("throws") {
            managerCall = "try manager.callThrows(\"\(fullyQualifiedName)\""
            tryIfThrowing = "try "
        } else {
            managerCall = "manager.call(\"\(fullyQualifiedName)\""
            tryIfThrowing = ""
        }
        if !parameters.isEmpty {
            managerCall += ", parameters: \(prepareEscapingParameters(parameters))"
        }
        managerCall += ", original: observed.map { o in return { (\(parametersSignature))\(returnSignature) in \(tryIfThrowing)o.\(rawName)(\(methodForwardingCallParameters(parameters))) } })"
        managerCall += "(\(methodForwardingCallParameters(parameters, ignoreSingleLabel: true)))"
        
        output += ""
        output += "\(accessibility.sourceName)\(isOverriding ? " override" : "") func \(rawName)(\(parametersSignature))\(returnSignature) {"
        output += "    return \(managerCall)"
        output += "}"
        return output
    }
    
    
    private static func generateStubbingWithIndentation(indentation: String = "", tokens: [Token]) -> [String] {
      return tokens.flatMap({ t in generateStubbingWithIndentation(indentation, token: t) })
    }
    
    private static func generateStubbingWithIndentation(indentation: String = "", token: Token) -> [String] {
        var output: [String] = []
        
        switch token {
        case let containerToken as ContainerToken:
            output += generateStubbingClass(containerToken)
            
        case let method as Method:
            output += generateStubbingMethod(method)
            
        default:
            break
        }
        
        return output.map { "\(indentation)\($0)" }
    }
    
    private static func generateStubbingClass(token: ContainerToken) -> [String] {
        let name = token.name
        let accessibility = token.accessibility
        let children = token.children
        
        guard accessibility != .Private else { return [] }
        var output: [String] = []
        
        output += "\(accessibility.sourceName) struct \(stubbingProxyName(name)): Cuckoo.StubbingProxy {"
        output += "    let handler: Cuckoo.StubbingHandler"
        output += ""
        output += "    \(accessibility.sourceName) init(handler: Cuckoo.StubbingHandler) {"
        output += "        self.handler = handler"
        output += "    }"
        output += generateStubbingWithIndentation("    ", tokens: children)
        output += ""
        output += "}"
        
        return output
    }
    
    private static func generateStubbingMethod(token: Method) -> [String] {
        let name = token.name
        let accessibility = token.accessibility
        let returnSignature = token.returnSignature
        let parameters = token.parameters
        
        guard accessibility != .Private else { return [] }
        var output: [String] = []
        let rawName = name.takeUntilStringOccurs("(") ?? ""
        
        let fullyQualifiedName = fullyQualifiedMethodName(name, parameters: parameters, returnSignature: returnSignature)
        let parametersSignature = prepareMatchableParameterSignature(parameters)
        let throwing = returnSignature.containsString("throws")
        
        var returnType: String
        if throwing {
            returnType = "Cuckoo.ToBeStubbedThrowingFunction"
        } else {
            returnType = "Cuckoo.ToBeStubbedFunction"
        }
        returnType += "<"
        returnType += "(\(parametersTupleType(parameters)))"
        returnType += ", "
        returnType += extractReturnType(returnSignature) ?? "Void"
        returnType += ">"
        
        var stubCall: String
        if throwing {
            stubCall = "handler.stubThrowing(\"\(fullyQualifiedName)\""
        } else {
            stubCall = "handler.stub(\"\(fullyQualifiedName)\""
        }
        if !parameters.isEmpty {
            stubCall += ", parameterMatchers: matchers"
        }
        stubCall += ")"
        
        output += ""
        output += "@warn_unused_result"
        output += "\(accessibility.sourceName) func \(rawName)\(prepareMatchableGenerics(parameters))(\(parametersSignature)) -> \(returnType) {"
        output += "    \(prepareParameterMatchers(parameters))"
        output += "    return \(stubCall)"
        output += "}"
        
        return output
    }
    
    private static func generateVerificationWithIndentation(indentation: String = "", tokens: [Token]) -> [String] {
      return tokens.flatMap({ t in generateVerificationWithIndentation(indentation, token: t) })
    }
    
    private static func generateVerificationWithIndentation(indentation: String = "", token: Token) -> [String] {
        var output: [String] = []
        
        switch token {
        case let containerToken as ContainerToken:
            output += generateVerificationClass(containerToken)
            
        case let method as Method:
            output += generateVerificationMethod(method)

        default:
            break
        }
        
        return output.map { "\(indentation)\($0)" }
    }
    
    private static func generateVerificationClass(token: ContainerToken) -> [String] {
        let name = token.name
        let accessibility = token.accessibility
        let children = token.children
        
        guard accessibility != .Private else { return [] }
        var output: [String] = []
        output += "\(accessibility.sourceName) struct \(verificationProxyName(name)): Cuckoo.VerificationProxy {"
        output += "    let handler: Cuckoo.VerificationHandler"
        output += ""
        output += "    \(accessibility.sourceName) init(handler: Cuckoo.VerificationHandler) {"
        output += "        self.handler = handler"
        output += "    }"
        output += generateVerificationWithIndentation("    ", tokens: children)
        output += ""
        output += "}"
        return output
    }
    
    private static func generateVerificationMethod(token: Method) -> [String] {
        let name = token.name
        let accessibility = token.accessibility
        let returnSignature = token.returnSignature
        let parameters = token.parameters
        
        guard accessibility != .Private else { return [] }
        var output: [String] = []
        let rawName = name.takeUntilStringOccurs("(") ?? ""
        
        let fullyQualifiedName = fullyQualifiedMethodName(name, parameters: parameters, returnSignature: returnSignature)
        let parametersSignature = prepareMatchableParameterSignature(parameters, addBeforeLastClosure: "__file: String = __FILE__, __line: UInt = __LINE__")
        
        let returnType = "Cuckoo.__DoNotUse<" + (extractReturnType(returnSignature) ?? "Void") + ">"
        
        var verifyCall = "handler.verify(\"\(fullyQualifiedName)\", file: __file, line: __line"
        if !parameters.isEmpty {
            verifyCall += ", parameterMatchers: matchers"
        }
        verifyCall += ")"
        
        output += ""
        output += "\(accessibility.sourceName) func \(rawName)\(prepareMatchableGenerics(parameters))(\(parametersSignature)) -> \(returnType){"
        output += "    \(prepareParameterMatchers(parameters))"
        output += "    return \(verifyCall)"
        output += "}"
        return output
    }
    
    private static func mockClassName(originalName: String) -> String {
        return "Mock" + originalName
    }
    
    private static func stubbingProxyName(originalName: String) -> String {
        return "__StubbingProxy_" + originalName
    }
    
    private static func verificationProxyName(originalName: String) -> String {
        return "__VerificationProxy_" + originalName
    }
    
    private static func fullyQualifiedMethodName(name: String, parameters: [MethodParameter], returnSignature: String) -> String {
        let parameterTypes = parameters.map { $0.type }
        let nameParts = name.componentsSeparatedByString(":")
        let lastNamePart = nameParts.last ?? ""
        
        return zip(nameParts.dropLast(), parameterTypes)
            .map { $0 + ":" + $1 }
            .joinWithSeparator(", ") + lastNamePart + returnSignature
    }
    
    private static func extractReturnType(returnSignature: String) -> String? {
        return returnSignature.trimmed.takeAfterStringOccurs("->")
    }
    
    private static func prepareEscapingParameters(parameters: [MethodParameter]) -> String {
        guard parameters.isEmpty == false else { return "" }
        let escapingParameters: [String] = parameters.map {
            if $0.attributes.contains(Attributes.noescape) || ($0.attributes.contains(Attributes.autoclosure) && !$0.attributes.contains(Attributes.escaping)) {
                return "Cuckoo.markerFunction()"
            } else {
                return $0.name
            }
        }
        
        if let firstParameter = escapingParameters.first where escapingParameters.count == 1 {
            return "(" + firstParameter + ")"
        }
        
        return "(" + methodCall(parameters, andValues: escapingParameters) + ")"
    }
    
    private static func prepareMatchableGenerics(parameters: [MethodParameter]) -> String {
        guard parameters.isEmpty == false else { return "" }
        
        let genericParameters = (1...parameters.count).map {
            "M\($0): Cuckoo.Matchable"
        }.joinWithSeparator(", ")
        
        let whereClause = parameters.enumerate().map {
            "M\($0 + 1).MatchedType == (\($1.type))"
        }.joinWithSeparator(", ")
        
        return "<\(genericParameters) where \(whereClause)>"
    }
    
    private static func prepareMatchableParameterSignature(parameters: [MethodParameter], addBeforeLastClosure: String? = nil) -> String {
        guard parameters.isEmpty == false else { return addBeforeLastClosure ?? "" }
        var labelAndType = parameters.enumerate().map {
            "\($1.labelAndNameAtPosition($0)): M\($0 + 1)"
        }
        if let addBeforeLastClosure = addBeforeLastClosure {
            if let last = labelAndType.last where last.containsString("->") {
                labelAndType.insert(addBeforeLastClosure, atIndex: labelAndType.endIndex.predecessor().predecessor())
            } else {
                labelAndType.append(addBeforeLastClosure)
            }
        }
        return labelAndType.joinWithSeparator(", ")
    }
    
    private static func prepareParameterMatchers(parameters: [MethodParameter]) -> String {
        guard parameters.isEmpty == false else { return "" }
        let matchers: [String] = parameters.enumerate().map {
            "parameterMatcher(\($1.name).matcher) { \(parameters.count > 1 ? "$0.\($1.labelNameOrPositionAtPosition($0))" : "$0") }"
        }
        
        return "let matchers: [Cuckoo.AnyMatcher<(\(parametersTupleType(parameters)))>] = [\(matchers.joinWithSeparator(", "))]"
    }
}