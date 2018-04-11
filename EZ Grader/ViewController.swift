//
//  ViewController.swift
//  EZ Grader
//
//  Copyright © 2018 RIT. All rights reserved.
//

import PDFKit

enum EZGraderMode {
    case viewPDFDocuments
    case freeHandAnnotate
    case textAnnotate
    case addGrade
}

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    let appFontSize: CGFloat = 30
    
    var ezGraderMode: EZGraderMode?
    var pdfView: PDFView!
    var path: UIBezierPath!
    var currentFreeHandPDFAnnotation: PDFAnnotation!
    var currentFreeHandPDFAnnotationPDFPage: PDFPage!
    var numberOfPagesPerPDFDocument: Int!
    var combinedPDFDocument: PDFDocument!
    var isPerPDFPageMode: Bool!
    var isDot: Bool!
    var appDefaultButtonTintColor: UIColor!
    var pdfDocumentFileNames: [String] = []
    
    //MARK: Properties
    @IBOutlet var freeHandAnnotateButton: UIBarButtonItem!
    @IBOutlet var textAnnotateButton: UIBarButtonItem!
    @IBOutlet var addGradeButton: UIBarButtonItem!
    @IBOutlet var saveButton: UIBarButtonItem!
    @IBOutlet var doneEditingButton: UIBarButtonItem!
    @IBOutlet var viewPerPDFPageButton: UIBarButtonItem!
    @IBOutlet var viewPerPDFDocumentButton: UIBarButtonItem!

    //MARK: Actions
    @IBAction func freeHandAnnotate(_ freeHandAnnotateButton: UIBarButtonItem) {
        self.path = UIBezierPath()

        self.pdfView.isUserInteractionEnabled = false
        
        self.ezGraderMode = EZGraderMode.freeHandAnnotate
        
        self.updateNavigationBar()
    }
    
    @IBAction func textAnnotate(_ textAnnotateButton: UIBarButtonItem) {
        self.pdfView.isUserInteractionEnabled = false
        
        self.ezGraderMode = EZGraderMode.textAnnotate
        
        self.updateNavigationBar()
    }
    
    @IBAction func addGrade(_ addGradeButton: UIBarButtonItem) {
        self.pdfView.isUserInteractionEnabled = false
        
        self.ezGraderMode = EZGraderMode.addGrade
        
        self.updateNavigationBar()
    }
    
    @IBAction func save(_ saveButton: UIBarButtonItem) {
        let documentsPath: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        
        //Maps a PDF document file name to a PDF page number, which in turns maps to an array containing grades on the PDF page identified
        //by the PDF page index sorted top to bottom as they appear on the page
        var allPDFDocumentGrades: [String: [Int: [String]]] = [:]
        
        var pdfPage: PDFPage
        
        var pdfDocumentToWrite: PDFDocument = PDFDocument()
        
        if self.isPerPDFPageMode {
            let numberOfPDFDocuments: Int = self.combinedPDFDocument.pageCount / self.numberOfPagesPerPDFDocument
            
            for pdfDocumentIndex: Int in 0...numberOfPDFDocuments - 1 {
                for pdfDocumentPageIndex: Int in 0...self.numberOfPagesPerPDFDocument - 1 {
                    pdfPage = self.combinedPDFDocument.page(at: (pdfDocumentPageIndex * numberOfPDFDocuments + pdfDocumentIndex))!
                    
                    self.updateGradesForPDFDocumentPage(pdfPage: pdfPage, allPDFDocumentGrades: &allPDFDocumentGrades, pdfDocumentIndex: pdfDocumentIndex, pdfDocumentPageIndex: pdfDocumentPageIndex)
                    
                    pdfDocumentToWrite.insert(pdfPage, at: pdfDocumentToWrite.pageCount)
                }
                
                pdfDocumentToWrite.write(toFile: "\(documentsPath)/\(self.pdfDocumentFileNames[pdfDocumentIndex]).pdf")
                
                pdfDocumentToWrite = PDFDocument()
            }
        } else {
            var pdfDocumentIndex: Int
            
            for combinedPDFDocumentPageIndex: Int in 0...self.combinedPDFDocument.pageCount - 1 {
                pdfPage = self.combinedPDFDocument.page(at: combinedPDFDocumentPageIndex)!
                
                pdfDocumentIndex = combinedPDFDocumentPageIndex / self.numberOfPagesPerPDFDocument
                
                self.updateGradesForPDFDocumentPage(pdfPage: pdfPage, allPDFDocumentGrades: &allPDFDocumentGrades, pdfDocumentIndex: pdfDocumentIndex, pdfDocumentPageIndex: combinedPDFDocumentPageIndex % self.numberOfPagesPerPDFDocument)
                
                pdfDocumentToWrite.insert(pdfPage, at: pdfDocumentToWrite.pageCount)
                
                if (combinedPDFDocumentPageIndex + 1) % self.numberOfPagesPerPDFDocument == 0 {
                    pdfDocumentToWrite.write(toFile: "\(documentsPath)/\(self.pdfDocumentFileNames[pdfDocumentIndex]).pdf")
                    
                    pdfDocumentToWrite = PDFDocument()
                }
            }
        }
        
        self.writeOutGradesAsCSV(grades: allPDFDocumentGrades)
    }
    
    @IBAction func doneEditing(_ doneEditingButton: UIBarButtonItem) {
        if self.ezGraderMode == EZGraderMode.freeHandAnnotate {
            self.currentFreeHandPDFAnnotation = nil
            self.currentFreeHandPDFAnnotationPDFPage = nil
        }
        
        self.pdfView.isUserInteractionEnabled = true
        
        self.ezGraderMode = EZGraderMode.viewPDFDocuments
        
        self.updateNavigationBar()
    }
    
    @IBAction func viewPerPDFPage(_ viewPerPDFPageButton: UIBarButtonItem) {
        if self.isPerPDFPageMode == true {
            return
        }
        
        self.isPerPDFPageMode = true
        
        self.viewPerPDFPageButton.tintColor = UIColor.red
        self.viewPerPDFDocumentButton.tintColor = self.appDefaultButtonTintColor
        
        let currentPDFPage: PDFPage = self.pdfView.currentPage!
        
        let perPDFPageCombinedPDFDocument = PDFDocument()
        
        let numberOfPDFDocuments: Int = self.combinedPDFDocument.pageCount / self.numberOfPagesPerPDFDocument
        
        for pdfDocumentPageIndex: Int in 0...self.numberOfPagesPerPDFDocument - 1 {
            for pdfDocumentIndex: Int in 0...numberOfPDFDocuments - 1 {
                perPDFPageCombinedPDFDocument.insert(self.combinedPDFDocument.page(at: pdfDocumentIndex * self.numberOfPagesPerPDFDocument + pdfDocumentPageIndex)!, at: perPDFPageCombinedPDFDocument.pageCount)
            }
        }
        
        self.combinedPDFDocument = perPDFPageCombinedPDFDocument
        
        self.pdfView.document = self.combinedPDFDocument
        
        self.pdfView.go(to: currentPDFPage)
    }
    
    @IBAction func viewPerPDFDocument(_ viewPerPDFDocumentButton: UIBarButtonItem) {
        if self.isPerPDFPageMode == false {
            return
        }
        
        self.isPerPDFPageMode = false
        
        self.viewPerPDFPageButton.tintColor = self.appDefaultButtonTintColor
        self.viewPerPDFDocumentButton.tintColor = UIColor.red
        
        let currentPDFPage: PDFPage = self.pdfView.currentPage!
        
        let perPDFDocumentCombinedPDFDocument = PDFDocument()
        
        let numberOfPDFDocuments: Int = self.combinedPDFDocument.pageCount / self.numberOfPagesPerPDFDocument
        
        for pdfDocumentIndex: Int in 0...numberOfPDFDocuments - 1 {
            for pdfDocumentPageIndex: Int in 0...self.numberOfPagesPerPDFDocument - 1 {
                perPDFDocumentCombinedPDFDocument.insert(self.combinedPDFDocument.page(at: pdfDocumentPageIndex * numberOfPDFDocuments + pdfDocumentIndex)!, at: perPDFDocumentCombinedPDFDocument.pageCount)
            }
        }
        
        self.combinedPDFDocument = perPDFDocumentCombinedPDFDocument
        
        self.pdfView.document = self.combinedPDFDocument
        
        self.pdfView.go(to: currentPDFPage)
    }
    
    @IBAction func startGrading(_ startGradingButton: UIButton) {
        let pdfDocumentURLs: [URL] = Bundle.main.urls(forResourcesWithExtension: "pdf", subdirectory: nil)!
        
        var pdfDocument: PDFDocument!
        
        for pdfDocumentURL: URL in pdfDocumentURLs {
            self.pdfDocumentFileNames.append(pdfDocumentURL.deletingPathExtension().lastPathComponent)
            
            pdfDocument = PDFDocument(url: pdfDocumentURL)
            
            if self.numberOfPagesPerPDFDocument == nil {
                self.numberOfPagesPerPDFDocument = pdfDocument.pageCount
            } else if self.numberOfPagesPerPDFDocument != pdfDocument.pageCount {
                // create the alert
                let pdfDocumentPageCountMismatchUIAlertController: UIAlertController = UIAlertController(title: "PDF Document Page Count Mismatch", message: "All of the PDF documents to be graded must have the same number of pages.", preferredStyle: UIAlertControllerStyle.alert)
                
                // add the actions (buttons)
                pdfDocumentPageCountMismatchUIAlertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                
                // show the alert
                self.present(pdfDocumentPageCountMismatchUIAlertController, animated: true, completion: nil)
                
                return
            }
        }
        
        startGradingButton.isHidden = true
        
        self.isPerPDFPageMode = true
        self.combinedPDFDocument = PDFDocument()
        
        for pdfDocumentPageIndex: Int in 0...self.numberOfPagesPerPDFDocument - 1 {
            for pdfDocumentURL: URL in pdfDocumentURLs {
                let pdfPage: PDFPage = (PDFDocument(url: pdfDocumentURL)!.page(at: pdfDocumentPageIndex))!
                
                self.combinedPDFDocument.insert(pdfPage, at: self.combinedPDFDocument.pageCount)
            }
        }
        
        self.pdfView = PDFView(frame: UIScreen.main.bounds)
        
        self.pdfView.displayMode = .singlePageContinuous
        self.pdfView.autoScales = true
        self.pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.pdfView.document = self.combinedPDFDocument
        
        self.view.addSubview(self.pdfView)
        
        self.ezGraderMode = EZGraderMode.viewPDFDocuments
        
        self.viewPerPDFPageButton.tintColor = UIColor.red
        
        self.navigationController?.isNavigationBarHidden = false
        
        self.updateNavigationBar()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.isNavigationBarHidden = true
        self.appDefaultButtonTintColor = self.viewPerPDFPageButton.tintColor
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.ezGraderMode == EZGraderMode.freeHandAnnotate || self.ezGraderMode == EZGraderMode.textAnnotate || self.ezGraderMode == EZGraderMode.addGrade {
            if let touch: UITouch = touches.first {
                let touchViewCoordinate: CGPoint = touch.location(in: self.pdfView)
                let pdfPageAtTouchedPosition: PDFPage = self.pdfView.page(for: touchViewCoordinate, nearest: true)!
                let pdfDocumentPageIndexAtTouchedPosition: Int = (self.pdfView.document?.index(for: pdfPageAtTouchedPosition))!
                let touchPDFPageCoordinate: CGPoint = self.pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
                
                if self.ezGraderMode == EZGraderMode.freeHandAnnotate {
                    self.path.move(to: touchPDFPageCoordinate)
                    
                    self.isDot = true
                    
                    if self.currentFreeHandPDFAnnotationPDFPage == nil {
                        self.currentFreeHandPDFAnnotationPDFPage = pdfPageAtTouchedPosition
                    }
                } else if self.ezGraderMode == EZGraderMode.textAnnotate {
                    self.showAddTextAnnotationInputDialog(touchPDFPageCoordinate: touchPDFPageCoordinate, pdfDocumentPageIndexAtTouchedPosition: pdfDocumentPageIndexAtTouchedPosition)
                } else if self.ezGraderMode == EZGraderMode.addGrade {
                    self.showAddGradeInputDialog(touchPDFPageCoordinate: touchPDFPageCoordinate, pdfDocumentPageIndexAtTouchedPosition: pdfDocumentPageIndexAtTouchedPosition)
                }
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.ezGraderMode == EZGraderMode.freeHandAnnotate {
            if let touch: UITouch = touches.first {
                let touchViewCoordinate: CGPoint = touch.location(in: self.pdfView)
                let pdfPageAtTouchedPosition: PDFPage = self.pdfView.page(for: touchViewCoordinate, nearest: true)!
                let pdfDocumentPageIndexAtTouchedPosition: Int = (self.pdfView.document?.index(for: pdfPageAtTouchedPosition))!
                let touchPDFPageCoordinate: CGPoint = self.pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
                
                if pdfPageAtTouchedPosition == self.currentFreeHandPDFAnnotationPDFPage {
                    self.path.addLine(to: touchPDFPageCoordinate)
                    
                    self.isDot = false
                    
                    if self.currentFreeHandPDFAnnotation != nil {
                        self.pdfView.document?.page(at: pdfDocumentPageIndexAtTouchedPosition)?.removeAnnotation(self.currentFreeHandPDFAnnotation)
                    }
                    
                    let currentAnnotationPDFBorder: PDFBorder = PDFBorder()
                    
                    currentAnnotationPDFBorder.lineWidth = 2.0
                    
                    self.currentFreeHandPDFAnnotation = PDFAnnotation(bounds: pdfPageAtTouchedPosition.bounds(for: PDFDisplayBox.cropBox), forType: PDFAnnotationSubtype.ink, withProperties: nil)
                    self.currentFreeHandPDFAnnotation.color = .red
                    self.currentFreeHandPDFAnnotation.add(self.path)
                    self.currentFreeHandPDFAnnotation.border = currentAnnotationPDFBorder
                    
                    self.pdfView.document?.page(at: pdfDocumentPageIndexAtTouchedPosition)?.addAnnotation(self.currentFreeHandPDFAnnotation)
                }
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.ezGraderMode == EZGraderMode.freeHandAnnotate && self.isDot {
            if let touch: UITouch = touches.first {
                let touchViewCoordinate: CGPoint = touch.location(in: self.pdfView)
                let pdfPageAtTouchedPosition: PDFPage = self.pdfView.page(for: touchViewCoordinate, nearest: true)!
                let pdfDocumentPageIndexAtTouchedPosition: Int = (self.pdfView.document?.index(for: pdfPageAtTouchedPosition))!
                let touchPDFPageCoordinate: CGPoint = self.pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
                
                if pdfPageAtTouchedPosition == self.currentFreeHandPDFAnnotationPDFPage {
                    self.path.addLine(to: CGPoint(x: touchPDFPageCoordinate.x + 1, y: touchPDFPageCoordinate.y))
                    self.path.addLine(to: CGPoint(x: touchPDFPageCoordinate.x + 1, y: touchPDFPageCoordinate.y + 1))
                    self.path.addLine(to: CGPoint(x: touchPDFPageCoordinate.x, y: touchPDFPageCoordinate.y + 1))
                    self.path.addLine(to: touchPDFPageCoordinate)
                    
                    if self.currentFreeHandPDFAnnotation != nil {
                        self.pdfView.document?.page(at: pdfDocumentPageIndexAtTouchedPosition)?.removeAnnotation(self.currentFreeHandPDFAnnotation)
                    }
                    
                    let currentPDFAnnotationPDFBorder: PDFBorder = PDFBorder()
                    
                    currentPDFAnnotationPDFBorder.lineWidth = 2.0
                    
                    self.currentFreeHandPDFAnnotation = PDFAnnotation(bounds: pdfPageAtTouchedPosition.bounds(for: PDFDisplayBox.cropBox), forType: PDFAnnotationSubtype.ink, withProperties: nil)
                    self.currentFreeHandPDFAnnotation.color = .red
                    self.currentFreeHandPDFAnnotation.add(self.path)
                    self.currentFreeHandPDFAnnotation.border = currentPDFAnnotationPDFBorder
                    
                    self.pdfView.document?.page(at: pdfDocumentPageIndexAtTouchedPosition)?.addAnnotation(self.currentFreeHandPDFAnnotation)
                }
            }
        }
    }
    
    private func updateGradesForPDFDocumentPage(pdfPage: PDFPage, allPDFDocumentGrades: inout [String: [Int: [String]]], pdfDocumentIndex: Int, pdfDocumentPageIndex: Int) -> Void {
        //Filter annotations on the page to only return grade annotations
        let sortedPDFPageGrades: [String] = pdfPage.annotations.filter({ (pdfAnnotation: PDFAnnotation) -> Bool in
            return pdfAnnotation.annotationKeyValues[PDFAnnotationKey.widgetCaption] as? String == "Grade Annotation"
        //Sort grade annotations on the page from top to bottom
        }).sorted(by: { (grade1PDFAnnotation: PDFAnnotation, grade2PDFAnnotation: PDFAnnotation) -> Bool in
            return self.pdfView.convert(grade1PDFAnnotation.bounds, from: pdfPage).maxY < self.pdfView.convert(grade2PDFAnnotation.bounds, from: pdfPage).maxY
        }).map({ (gradePDFAnnotation: PDFAnnotation) -> String in
            return gradePDFAnnotation.contents!
        })
        
        if sortedPDFPageGrades.count > 0 {
            var currentPDFDocumentGrades: [Int: [String]] = allPDFDocumentGrades.keys.contains(self.pdfDocumentFileNames[pdfDocumentIndex]) ? allPDFDocumentGrades[self.pdfDocumentFileNames[pdfDocumentIndex]]! : [:]
            
            currentPDFDocumentGrades[pdfDocumentPageIndex + 1] = sortedPDFPageGrades
            
            allPDFDocumentGrades[self.pdfDocumentFileNames[pdfDocumentIndex]] = currentPDFDocumentGrades
        }
    }
    
    private func writeOutGradesAsCSV(grades: [String: [Int: [String]]]) -> Void {
        var csvFileContentsString: String = "Page Number,Question Number"
         
        for pdfDocumentFileName: String in self.pdfDocumentFileNames {
            csvFileContentsString += ",\"\(pdfDocumentFileName)\""
        }
        
        csvFileContentsString += "\n"
        
        if grades.keys.count == 0 {
            csvFileContentsString += "No grades have been entered yet.\n"
        } else {
            let pdfDocumentPageNumbersHavingGradesSorted: [Int] = grades[self.pdfDocumentFileNames[0]]!.keys.sorted(by: { (pdfDocumentPage1Number: Int, pdfDocumentPage2Number: Int) -> Bool in
                return pdfDocumentPage1Number < pdfDocumentPage2Number
            })
            
            for pdfDocumentPageNumberHavingGrades: Int in pdfDocumentPageNumbersHavingGradesSorted {
                for pdfDocumentPageQuestionNumber: Int in 1...(grades[self.pdfDocumentFileNames[0]]![pdfDocumentPageNumberHavingGrades]?.count)! {
                    if pdfDocumentPageQuestionNumber == 1 {
                        csvFileContentsString += "Page \(pdfDocumentPageNumberHavingGrades)"
                    }
                    
                    csvFileContentsString += ",Question \(pdfDocumentPageQuestionNumber)"
                    
                    for pdfDocumentFileName: String in self.pdfDocumentFileNames {
                        csvFileContentsString += ",\(grades[pdfDocumentFileName]![pdfDocumentPageNumberHavingGrades]![pdfDocumentPageQuestionNumber - 1])"
                    }
                    
                    csvFileContentsString += "\n"
                }
            }
            
            csvFileContentsString += "TOTAL,-"
            
            var pointsEarnedMissing: Bool = false
            var pointsEarnedRunningTotal: Double
            var maximumPointsRunningTotal: Double
            var gradeComponentsTrimmedWhitespace: [String]
            
            for pdfDocumentFileName: String in self.pdfDocumentFileNames {
                pointsEarnedRunningTotal = 0
                maximumPointsRunningTotal = 0
                
                for pdfDocumentPageNumberHavingGrades: Int in pdfDocumentPageNumbersHavingGradesSorted {
                    for grade: String in grades[pdfDocumentFileName]![pdfDocumentPageNumberHavingGrades]! {
                        gradeComponentsTrimmedWhitespace = grade.components(separatedBy: "/").map({ (gradeComponent: String) -> String in
                            return gradeComponent.trimmingCharacters(in: CharacterSet.whitespaces)
                        })
                    
                        if !pointsEarnedMissing {
                            if let pointsEarned: Double = Double(gradeComponentsTrimmedWhitespace[0]) {
                                pointsEarnedRunningTotal += pointsEarned
                            } else {
                                pointsEarnedMissing = true
                            }
                        }
                        
                        maximumPointsRunningTotal += Double(gradeComponentsTrimmedWhitespace[1])!
                    }
                }
                
                csvFileContentsString += !pointsEarnedMissing ? ",\(pointsEarnedRunningTotal)" : ",?"
                
                csvFileContentsString += " / \(maximumPointsRunningTotal) ("
                
                csvFileContentsString += !pointsEarnedMissing ? "\((pointsEarnedRunningTotal / maximumPointsRunningTotal * 10000).rounded(FloatingPointRoundingRule.toNearestOrEven) / 100)" : "?"
                
                csvFileContentsString += "%)"
            }
            
            csvFileContentsString += "\n"
        }
        
        let fileManager = FileManager.default
        do {
            let path = try fileManager.url(for: .documentDirectory, in: .allDomainsMask, appropriateFor: nil, create: false)
            let fileURL = path.appendingPathComponent("CSVRec.csv")
            try csvFileContentsString.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("error creating file")
        }
    }
    
    private func showAddTextAnnotationInputDialog(touchPDFPageCoordinate: CGPoint, pdfDocumentPageIndexAtTouchedPosition: Int) -> Void {
        let addTextAnnotationUIAlertController = UIAlertController(title: "Add Text Annotation", message: "", preferredStyle: .alert)
        
        let addTextAnnotationUIAlertAction: UIAlertAction = UIAlertAction(title: "Add Text Annotation", style: .default) { (alert: UIAlertAction!) in
            let enteredText: String = (addTextAnnotationUIAlertController.textFields?[0].text)!
            let enteredTextSize: CGSize = self.getTextSize(text: enteredText + "  ")
            
            let textAnnotationFreeTextPDFAnnotation: PDFAnnotation = PDFAnnotation(bounds: CGRect(origin: touchPDFPageCoordinate, size: CGSize(width: enteredTextSize.height, height: enteredTextSize.width)), forType: .freeText, withProperties: nil)
            
            textAnnotationFreeTextPDFAnnotation.fontColor = UIColor.red
            textAnnotationFreeTextPDFAnnotation.font = UIFont.systemFont(ofSize: self.appFontSize)
            textAnnotationFreeTextPDFAnnotation.color = UIColor.clear
            textAnnotationFreeTextPDFAnnotation.isReadOnly = true
            textAnnotationFreeTextPDFAnnotation.contents = enteredText
            textAnnotationFreeTextPDFAnnotation.setValue("Text Annotation", forAnnotationKey: PDFAnnotationKey.widgetCaption)
            
            self.pdfView.document?.page(at: pdfDocumentPageIndexAtTouchedPosition)?.addAnnotation(textAnnotationFreeTextPDFAnnotation)
        }
        
        let cancelAddTextAnnotationUIAlertAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { (alert: UIAlertAction!) in }
        
        addTextAnnotationUIAlertController.addTextField { (textField) in
            textField.placeholder = "Text Annotation"
        }
        
        addTextAnnotationUIAlertController.addAction(addTextAnnotationUIAlertAction)
        addTextAnnotationUIAlertController.addAction(cancelAddTextAnnotationUIAlertAction)
        
        self.present(addTextAnnotationUIAlertController, animated: true, completion: nil)
    }
    
    private func showAddGradeInputDialog(touchPDFPageCoordinate: CGPoint, pdfDocumentPageIndexAtTouchedPosition: Int) -> Void {
        let addGradeUIAlertController = UIAlertController(title: "Add Grade", message: "", preferredStyle: .alert)
        
        let addGradeUIAlertAction: UIAlertAction = UIAlertAction(title: "Add Grade", style: .default) { (alert: UIAlertAction!) in
            self.addGradeToAllPDFDocuments(pointsEarned: (addGradeUIAlertController.textFields?[0].text)!, maximumPoints: (addGradeUIAlertController.textFields?[1].text)!, touchPDFPageCoordinate: touchPDFPageCoordinate, pdfDocumentPageIndexAtTouchedPosition: pdfDocumentPageIndexAtTouchedPosition)
        }
        
        let cancelAddGradeUIAlertAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { (alert: UIAlertAction!) in }
        
        addGradeUIAlertController.addTextField { (textField) in
            textField.placeholder = "Points Earned"
            textField.keyboardType = UIKeyboardType.decimalPad
        }
        
        addGradeUIAlertController.addTextField { (textField) in
            textField.placeholder = "Maximum Points"
            textField.keyboardType = UIKeyboardType.decimalPad
        }
        
        addGradeUIAlertController.addAction(addGradeUIAlertAction)
        addGradeUIAlertController.addAction(cancelAddGradeUIAlertAction)
        
        self.present(addGradeUIAlertController, animated: true, completion: nil)
    }
    
    private func addGradeToAllPDFDocuments(pointsEarned: String, maximumPoints: String, touchPDFPageCoordinate: CGPoint, pdfDocumentPageIndexAtTouchedPosition: Int) -> Void {
        let gradeForCurrentPDFDocument: String = pointsEarned + " / " + maximumPoints
        let gradeForOtherPDFDocuments: String =  "? / " + maximumPoints
        
        if self.isPerPDFPageMode {
            let numberOfPDFDocuments: Int = self.combinedPDFDocument.pageCount / self.numberOfPagesPerPDFDocument
            let indexOfPDFDocumentPageOfFirstPDFDocument: Int = pdfDocumentPageIndexAtTouchedPosition - (pdfDocumentPageIndexAtTouchedPosition % numberOfPDFDocuments)
            
            for indexOfPDFDocumentPageToAddAnnotationTo: Int in indexOfPDFDocumentPageOfFirstPDFDocument...indexOfPDFDocumentPageOfFirstPDFDocument + numberOfPDFDocuments - 1 {
                self.pdfView.document?.page(at: indexOfPDFDocumentPageToAddAnnotationTo)?.addAnnotation(createGradeFreeTextAnnotation(gradeText: indexOfPDFDocumentPageToAddAnnotationTo == pdfDocumentPageIndexAtTouchedPosition ? gradeForCurrentPDFDocument : gradeForOtherPDFDocuments, touchPDFPageCoordinate: touchPDFPageCoordinate))
            }
        } else {
            for indexOfPDFDocumentPageToAddAnnotationTo: Int in stride(from: pdfDocumentPageIndexAtTouchedPosition % self.numberOfPagesPerPDFDocument, to: self.combinedPDFDocument.pageCount - 1, by: self.numberOfPagesPerPDFDocument) {
                self.pdfView.document?.page(at: indexOfPDFDocumentPageToAddAnnotationTo)?.addAnnotation(createGradeFreeTextAnnotation(gradeText: indexOfPDFDocumentPageToAddAnnotationTo == pdfDocumentPageIndexAtTouchedPosition ? gradeForCurrentPDFDocument : gradeForOtherPDFDocuments, touchPDFPageCoordinate: touchPDFPageCoordinate))
            }
        }
    }
    
    private func createGradeFreeTextAnnotation(gradeText: String, touchPDFPageCoordinate: CGPoint) -> PDFAnnotation {
        let gradeTextSize: CGSize = self.getTextSize(text: gradeText + "  ")
        
        let gradeFreeTextPDFAnnotation: PDFAnnotation = PDFAnnotation(bounds: CGRect(origin: touchPDFPageCoordinate, size: CGSize(width: gradeTextSize.height, height: gradeTextSize.width)), forType: .freeText, withProperties: nil)
        
        gradeFreeTextPDFAnnotation.fontColor = UIColor.red
        gradeFreeTextPDFAnnotation.font = UIFont.systemFont(ofSize: self.appFontSize)
        gradeFreeTextPDFAnnotation.color = UIColor.clear
        gradeFreeTextPDFAnnotation.isReadOnly = true
        gradeFreeTextPDFAnnotation.contents = gradeText
        gradeFreeTextPDFAnnotation.setValue("Grade Annotation", forAnnotationKey: PDFAnnotationKey.widgetCaption)
        
        return gradeFreeTextPDFAnnotation
    }
    
    private func getTextSize(text: String) -> CGSize {
        let font: UIFont = UIFont.systemFont(ofSize: self.appFontSize)
        let fontAttributes: [NSAttributedStringKey: UIFont] = [NSAttributedStringKey.font: font]
        
        return text.size(withAttributes: fontAttributes)
    }
    
    private func updateNavigationBar() -> Void {
        switch self.ezGraderMode {
        case .viewPDFDocuments?:
            self.navigationItem.leftBarButtonItems = [self.freeHandAnnotateButton, self.textAnnotateButton, self.addGradeButton, self.saveButton]
            self.navigationItem.rightBarButtonItems = [self.viewPerPDFDocumentButton, self.viewPerPDFPageButton]
            self.navigationItem.title = ""
        case .freeHandAnnotate?,
             .textAnnotate?,
             .addGrade?:
            self.navigationItem.leftBarButtonItems = [self.doneEditingButton]
            self.navigationItem.rightBarButtonItems = []
            
            switch self.ezGraderMode {
            case .freeHandAnnotate?,
                 .textAnnotate?:
                self.navigationItem.title = "Annotating"
            case .addGrade?:
                self.navigationItem.title = "Adding Grades"
            default:
                break
            }
        default:
            break
        }
    }
}
