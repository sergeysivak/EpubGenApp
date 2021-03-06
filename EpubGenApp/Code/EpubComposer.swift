//
//  EpubComposer.swift
//  EpubGenApp
//
//  Created by Stanislav Shemiakov on 30.06.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Foundation

protocol EpubComposerDelegate: AnyObject {
    func event(message: String)
}

class EpubComposer {
    
    let fileManager = FileManager.default
    lazy var spanGenerator = ColoredSpanGenerator()
    lazy var smilGenerator = SmilGenerator()
    weak var delegate: EpubComposerDelegate?
    
    func compose(inputEpubFolderURL: URL?,
                 inputAudioFileURL: URL?,
                 inputTimingFileURL: URL?,
                 inputTimingOffset: TimeInterval,
                 outputFileName: String?,
                 outputTitle: String?,
                 outputEpubFolderURL: URL?,
                 outputRawFolderURL: URL?) throws {
        guard let inputEpubFolderURL = inputEpubFolderURL else {
            throw "inputEpubFolderURL is missing"
        }
        guard let inputAudioFileURL = inputAudioFileURL else {
            throw "inputAudioFileURL is missing"
        }
        guard let inputTimingFileURL = inputTimingFileURL else {
            throw "inputTimingFileURL is missing"
        }
        guard let outputFileName = outputFileName else {
            throw "outputFileName is missing"
        }
        guard let outputTitle = outputTitle else {
            throw "outputTitle is missing"
        }
        guard let outputEpubFolderURL = outputEpubFolderURL else {
            throw "outputEpubFolderURL is missing"
        }
        guard let outputRawFolderURL = outputRawFolderURL else {
            throw "outputRawFolderURL is missing"
        }
        fileManager.removeIfExists(at: outputEpubFolderURL)
        fileManager.removeIfExists(at: outputRawFolderURL)
        
        try fileManager.createDirectory(at: outputEpubFolderURL,
                                        withIntermediateDirectories: true,
                                        attributes: nil)
        try fileManager.createFile(from: "application/epub+zip",
                                   directoryURL: outputEpubFolderURL,
                                   name: "mimetype")
        
        let metaInfFolderURL = outputEpubFolderURL.appendingPathComponent("META-INF")
        try fileManager.createDirectory(at: metaInfFolderURL,
                                        withIntermediateDirectories: true,
                                        attributes: nil)
        guard let inputContainerURL = Bundle.main.url(forResource: "container",
                                                      withExtension: "xml") else
        {
            throw "input \"container.xml\" bundle resource is missing"
        }
        let outputContainerURL = metaInfFolderURL
            .appendingPathComponent("container")
            .appendingPathExtension("xml")
        try fileManager.copyItem(at: inputContainerURL,
                                 to: outputContainerURL)
        
        let oebpsFolderURL = outputEpubFolderURL.appendingPathComponent("OEBPS")
        try fileManager.createDirectory(at: oebpsFolderURL,
                                        withIntermediateDirectories: true,
                                        attributes: nil)
        
        let inputGoogleDocFolderURL = inputEpubFolderURL.appendingPathComponent("GoogleDoc")
        let inputImagesFolderURL = inputGoogleDocFolderURL.appendingPathComponent("images")
        let imageURLs: [URL]
        if fileManager.directoryExists(atPath: inputImagesFolderURL.path) {
            imageURLs = fileManager.files(inDirectory: inputImagesFolderURL)
        } else {
            imageURLs = []
        }
        if imageURLs.contains(where: { !(["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased())) }) {
            throw "unexpected image URL found in \(imageURLs)"
        }
        
        if !imageURLs.isEmpty {
            let outputImagesFolderURL = oebpsFolderURL.appendingPathComponent("Images")
            try fileManager.createDirectory(at: outputImagesFolderURL,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
            for inputImageURL in imageURLs {
                let outputImageURL = outputImagesFolderURL.appendingPathComponent(inputImageURL.lastPathComponent)
                try fileManager.copyItem(at: inputImageURL,
                                         to: outputImageURL)
            }
        }
        
        guard let inputPackageTemplateURL = Bundle.main.url(forResource: "package",
                                                            withExtension: "opf") else
        {
            throw "inputPackageTemplateURL is missing"
        }
        
        delegate?.event(message: "Composing package.opf")
        
        let inputPackageTemplateString = try String(contentsOf: inputPackageTemplateURL)
        var outputPackageString = inputPackageTemplateString.replacingOccurrences(of: "$#outputFileName#$", with: outputFileName)
        outputPackageString = outputPackageString.replacingOccurrences(of: "$#outputTitle#$", with: outputTitle)
        let mediaDuration = try fileManager.duration(for: inputAudioFileURL)
        let mediaDurationString = DateFormatter.packageFormatter.string(from: Date(timeInterval: mediaDuration,
                                                                                   since: DateFormatter.smilReferenceDate))
        outputPackageString = outputPackageString.replacingOccurrences(of: "$#mediaDuration#$", with: mediaDurationString)
        let inputPackageURL = inputGoogleDocFolderURL
            .appendingPathComponent("package")
            .appendingPathExtension("opf")
        let inputPackageString = try String(contentsOf: inputPackageURL)
        guard let modifiedDate = inputPackageString.findSubstrings(between: "<meta property=\"dcterms:modified\">", and: "</meta>").first else {
            throw "failed to find modifiedDate in \(inputPackageURL)"
        }
        guard let uid = inputPackageString.findSubstrings(between: "<dc:identifier id=\"uid\">", and: "</dc:identifier>").first else {
            throw "failed to find uid in \(inputPackageURL)"
        }
        outputPackageString = outputPackageString.replacingOccurrences(of: "$#modifiedDate#$", with: modifiedDate)
        outputPackageString = outputPackageString.replacingOccurrences(of: "$#uid#$", with: uid)
        
        var imageItemsString = ""
        for imageURL in imageURLs {
            let imageItem = "\n        <item id=\"\(imageURL.deletingPathExtension().lastPathComponent)\" href=\"Images/\(imageURL.lastPathComponent)\" media-type=\"image/png\"/>"
            imageItemsString.append(imageItem)
        }
        outputPackageString = outputPackageString.replacingOccurrences(of: "$#imageItems#$", with: imageItemsString)
        
        try fileManager.createFile(from: outputPackageString,
                                   directoryURL: oebpsFolderURL,
                                   name: "package",
                                   fileExtension: "opf")
        
        delegate?.event(message: "Copying audio")
        
        let audioFolderURL = oebpsFolderURL.appendingPathComponent("Audio")
        try fileManager.createDirectory(at: audioFolderURL,
                                        withIntermediateDirectories: true,
                                        attributes: nil)
        let outputAudioFileURL = audioFolderURL
            .appendingPathComponent(outputFileName)
            .appendingPathExtension("mp3")
        try fileManager.copyItem(at: inputAudioFileURL,
                                 to: outputAudioFileURL)
        
        let textFolderURL = oebpsFolderURL.appendingPathComponent("Text")
        try fileManager.createDirectory(at: textFolderURL,
                                        withIntermediateDirectories: true,
                                        attributes: nil)
        
        guard let inputNavURL = Bundle.main.url(forResource: "nav",
                                                withExtension: "xhtml") else
        {
            throw "inputNavURL is missing"
        }
        let inputNavString = try String(contentsOf: inputNavURL)
        var outputNavString = inputNavString.replacingOccurrences(of: "$#outputFileName#$", with: outputFileName)
        outputNavString = outputNavString.replacingOccurrences(of: "$#outputTitle#$", with: outputTitle)
        try fileManager.createFile(from: outputNavString,
                                   directoryURL: textFolderURL,
                                   name: "nav",
                                   fileExtension: "xhtml")
        
        delegate?.event(message: "Composing xhtml")
        
        let inputXHTMLFileURL = try FileManager.default
            .contentsOfDirectory(at: inputGoogleDocFolderURL, includingPropertiesForKeys: .none, options: [])
            .filter({ $0.pathExtension == "xhtml" })
            .first(where: { $0.lastPathComponent != "nav.xhtml" })!
        
        let xhtmlInputString = try String(contentsOf: inputXHTMLFileURL)
        let xhtmlOutput = try spanGenerator.output(input: xhtmlInputString,
                                                   title: outputTitle,
                                                   timingData: nil)
        try fileManager.createFile(from: xhtmlOutput.string,
                                   directoryURL: textFolderURL,
                                   name: outputFileName,
                                   fileExtension: "xhtml")
        
        delegate?.event(message: "Composing smil")
        
        let timingInputString = try String(contentsOf: inputTimingFileURL)
        let smilTextSource = "\(outputFileName).xhtml"
        let smilAudioSource = "../Audio/\(outputFileName).mp3"
        let timingOutput = smilGenerator.smil(from: timingInputString,
                                              textPath: smilTextSource,
                                              audioPath: smilAudioSource,
                                              offset: inputTimingOffset)
        
        guard xhtmlOutput.spansCount == timingOutput.parsCount else {
            throw "xhtml output spans count (\(xhtmlOutput.spansCount)) != timing output pars count (\(timingOutput.parsCount))"
        }
        
        try fileManager.createFile(from: timingOutput.string,
                                   directoryURL: textFolderURL,
                                   name: outputFileName,
                                   fileExtension: "xhtml.smil")
        
        // MARK: - raw iOS generation
        delegate?.event(message: "Composing raw folder")
        
        try fileManager.createDirectory(at: outputRawFolderURL,
                                        withIntermediateDirectories: true,
                                        attributes: nil)
        if !imageURLs.isEmpty {
            for inputImageURL in imageURLs {
                let outputImageURL = outputRawFolderURL.appendingPathComponent(inputImageURL.lastPathComponent)
                try fileManager.copyItem(at: inputImageURL,
                                         to: outputImageURL)
            }
        }
        
        let outputRawAudioFileURL = outputRawFolderURL
            .appendingPathComponent(outputFileName)
            .appendingPathExtension("mp3")
        try fileManager.copyItem(at: inputAudioFileURL,
                                 to: outputRawAudioFileURL)
        
        delegate?.event(message: "Composing raw xhtml")
        
        let timingData = ColoredSpanGenerator.TimingData(inputString: timingInputString,
                                                         offset: inputTimingOffset)
        let xhtmlRawOutput = try spanGenerator.output(input: xhtmlInputString,
                                                      title: outputTitle,
                                                      timingData: timingData)
        try fileManager.createFile(from: xhtmlRawOutput.string,
                                   directoryURL: outputRawFolderURL,
                                   name: outputFileName,
                                   fileExtension: "xhtml")
    }
    
}
