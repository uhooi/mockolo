import XCTest
import MockoloFramework

class MockoloTestCase: XCTestCase {
    var srcFilePathsCount = 1
    var mockFilePathsCount = 1
    
    let bundle = Bundle(for: MockoloTestCase.self)
    
    lazy var dstFilePath: String = {
        return bundle.bundlePath + "/Dst.swift"
    }()
    
    lazy var srcFilePaths: [String] = {
        var idx = 0
        var paths = [String]()
        let prefix = bundle.bundlePath + "/Src"
        let suffix = ".swift"
        while idx < srcFilePathsCount {
            let path = prefix + "\(idx)" + suffix
            paths.append(path)
            idx += 1
        }
        return paths
    }()
    
    lazy var mockFilePaths: [String] = {
        var idx = 0
        var paths = [String]()
        let prefix = bundle.bundlePath + "/Mocks"
        let suffix = ".swift"
        while idx < mockFilePathsCount {
            let path = prefix + "\(idx)" + suffix
            paths.append(path)
            idx += 1
        }
        return paths
    }()
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let created = FileManager.default.createFile(atPath: dstFilePath, contents: nil, attributes: nil)
        XCTAssert(created)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try? FileManager.default.removeItem(atPath: dstFilePath)
        for srcpath in srcFilePaths {
            try? FileManager.default.removeItem(atPath: srcpath)
        }
        for mockpath in mockFilePaths {
            try? FileManager.default.removeItem(atPath: mockpath)
        }
    }
    
    func verify(srcContent: String, mockContent: String? = nil, dstContent: String, header: String = "", declType: DeclType = .protocolType, useTemplateFunc: Bool = false, useMockObservable: Bool = false, testableImports: [String]? = [], allowSetCallCount: Bool = false, mockFinal: Bool = false, enableFuncArgsHistory: Bool = false, concurrencyLimit: Int? = 1) {
        var mockList: [String]?
        if let mock = mockContent {
            if mockList == nil {
                mockList = [String]()
            }
            mockList?.append(mock)
        }
        verify(srcContents: [srcContent], mockContents: mockList, dstContent: dstContent, header: header, declType: declType, useTemplateFunc: useTemplateFunc, useMockObservable: useMockObservable, testableImports: testableImports, allowSetCallCount: allowSetCallCount, mockFinal: mockFinal, enableFuncArgsHistory: enableFuncArgsHistory, concurrencyLimit: concurrencyLimit)
    }
    
    func verify(srcContents: [String], mockContents: [String]?, dstContent: String, header: String, declType: DeclType, useTemplateFunc: Bool, useMockObservable: Bool, testableImports: [String]?, allowSetCallCount: Bool, mockFinal: Bool, enableFuncArgsHistory: Bool, concurrencyLimit: Int?) {
        var index = 0
        srcFilePathsCount = srcContents.count
        mockFilePathsCount = mockContents?.count ?? 0
        
        for src in srcContents {
            if index < srcContents.count {
                let srcCreated = FileManager.default.createFile(atPath: srcFilePaths[index], contents: src.data(using: .utf8), attributes: nil)
                index += 1
                XCTAssert(srcCreated)
            }
        }
        
        let macroStart = String.poundIf + "MOCK"
        let macroEnd = String.poundEndIf
        
        let headerStr = header + String.headerDoc
        index = 0
        if let mockContents = mockContents {
            
            for mockContent in mockContents {
                
                let formattedMockContent = """
                \(headerStr)
                \(macroStart)
                \(mockContent)
                \(macroEnd)
                """
                let mockCreated = FileManager.default.createFile(atPath: mockFilePaths[index], contents: formattedMockContent.data(using: .utf8), attributes: nil)
                index += 1
                XCTAssert(mockCreated)
            }
        }
        
        let formattedDstContent = """
        \(headerStr)
        \(macroStart)
        \(dstContent)
        \(macroEnd)
        """
        
        try? generate(sourceDirs: nil,
                      sourceFiles: srcFilePaths,
                      parser: SourceParser(),
                      exclusionSuffixes: ["Mocks", "Tests"],
                      mockFilePaths: mockFilePaths,
                      annotation: String.mockAnnotation,
                      header: header,
                      macro: "MOCK",
                      declType: declType,
                      useTemplateFunc: useTemplateFunc,
                      useMockObservable: useMockObservable,
                      allowSetCallCount: allowSetCallCount,
                      enableFuncArgsHistory: enableFuncArgsHistory,
                      mockFinal: mockFinal,
                      testableImports: testableImports,
                      customImports: nil,
                      excludeImports: nil,
                      to: dstFilePath,
                      loggingLevel: 3,
                      concurrencyLimit: concurrencyLimit,
            onCompletion: { ret in
                let output = (try? String(contentsOf: URL(fileURLWithPath: self.dstFilePath), encoding: .utf8)) ?? ""
                let outputContents = output.components(separatedBy:  .whitespacesAndNewlines).filter{!$0.isEmpty}
                let fixtureContents = formattedDstContent.components(separatedBy: .whitespacesAndNewlines).filter{!$0.isEmpty}
                #if TEST
                print(output)
                #endif
                XCTAssert(fixtureContents == outputContents)
        })
    }
}

