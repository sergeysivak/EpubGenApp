//
//  TextExtension.swift
//  EpubGenApp
//
//  Created by Stanislav Shemiakov on 28.07.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Foundation

extension String {
    
    private func regExpDetectingSubstring(between str1: String,
                                          and str2: String) -> String {
        return "(?:\(str1))(.*?)(?:\(str2))"
    }
    
    func matches(for regex: String) -> [NSTextCheckingResult] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self,
                                        range: NSRange(startIndex..., in: self))
            return results
        } catch {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    
    func findSubstrings(between subString1: String,
                        and subString2: String,
                        exclusive: Bool = true) -> [String] {
        let matches = self.matches(for: regExpDetectingSubstring(between: subString1, and: subString2))
        if exclusive {
            return matches.map {
                String(self[Range($0.range(at: 1), in: self)!])
            }
        }
        return matches.map {
            String(self[Range($0.range, in: self)!])
        }
    }
    
    func replacingOccurrences(from subString1: String,
                              to subString2: String,
                              with replacement: String) -> String {
        let regExpr = regExpDetectingSubstring(between: subString1,
                                               and: subString2)
        return replacingOccurrences(of: regExpr,
                                    with: replacement,
                                    options: .regularExpression)
    }
    
    func slices(from subString1: String,
                to subString2: String) -> [SubSequence] {
        let regExpr = regExpDetectingSubstring(between: subString1,
                                               and: subString2)
        let sliceRanges = ranges(of: regExpr,
                                 options: .regularExpression)
        return sliceRanges.map { self[$0] }
    }
    
    public func ranges(of searchString: String,
                       options: String.CompareOptions = [],
                       range: Range<String.Index>? = nil,
                       locale: Locale? = nil) -> [Range<String.Index>] {
        let slice = (range == nil) ? self[...] : self[range!]
        var previousEnd = slice.startIndex
        var ranges = [Range<String.Index>]()
        var sliceRange: Range<Index>? {
            return slice.range(of: searchString,
                               options: options,
                               range: previousEnd ..< slice.endIndex,
                               locale: locale)
        }
        while let newRange = sliceRange {
            if previousEnd != endIndex {
                previousEnd = index(after: newRange.lowerBound)
            }
            ranges.append(newRange)
        }
        return ranges
    }
    
    var range: Range<Index> {
        return Range<Index>(uncheckedBounds: (lower: startIndex, upper: endIndex))
    }
    
    static let softHyphen = "\u{00AD}"
    
    func hyphenated(with hyphen: String = .softHyphen,
                    locale: Locale) throws -> String {
        guard locale.isHyphenationAvailable else {
            throw "Hyphenation isn't available for '\(locale.identifier)' locale"
        }
        let string: NSMutableString = NSMutableString(string: self)
        var hyphenationLocations = [CUnsignedChar](repeating: 0, count: Int(string.length))
        let range: CFRange = CFRangeMake(0, string.length)
        let cfLocale = locale as CFLocale
        for i in 0..<string.length {
            let location = CFStringGetHyphenationLocationBeforeIndex(string, i, range, 0, cfLocale, nil)
            if(location >= 0 && location < string.length)
            {
                hyphenationLocations[location] = 1;
            }
        }
        for i in (0..<string.length).reversed() {
            if hyphenationLocations[i] > 0 {
                string.insert(hyphen, at: i)
            }
        }
        return string as String
    }
    
    func attributedFromHTML() throws -> NSMutableAttributedString {
        let data = Data(utf8)
        let output = try NSMutableAttributedString(data: data,
                                                   options: [.documentType: NSAttributedString.DocumentType.html],
                                                   documentAttributes: nil)
        return output
    }
    
}

extension Locale {
    
    var isHyphenationAvailable: Bool {
        return CFStringIsHyphenationAvailableForLocale(self as CFLocale)
    }
    
}

