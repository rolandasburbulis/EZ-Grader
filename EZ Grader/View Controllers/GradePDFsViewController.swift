//
//  GradePDFsViewController.swift
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

class GradePDFsViewController: UIViewController, UIGestureRecognizerDelegate {
    let appFontSize: CGFloat = 30
    
    var ezGraderMode: EZGraderMode?
    var path: UIBezierPath!
    var currentFreeHandPDFAnnotation: PDFAnnotation!
    var currentFreeHandPDFAnnotationPDFPage: PDFPage!
    var leftCurrentPageWhenFreeHandAnnotating: Bool!
    var numberOfPagesPerPDFDocument: Int!
    var combinedPDFDocument: PDFDocument!
    var isPerPDFPageMode: Bool!
    var isDot: Bool!
    var appDefaultButtonTintColor: UIColor!
    var pdfDocumentFileNames: [String] = []
    
    //MARK: Properties
    @IBOutlet weak var pdfView: PDFView!
    @IBOutlet var overlayView: UIView!
    @IBOutlet var uiActivityIndicatorView: UIActivityIndicatorView!
    @IBOutlet var freeHandAnnotateButton: UIBarButtonItem!
    @IBOutlet var textAnnotateButton: UIBarButtonItem!
    @IBOutlet var addGradeButton: UIBarButtonItem!
    @IBOutlet var saveButton: UIBarButtonItem!
    @IBOutlet var viewPerPDFPageButton: UIBarButtonItem!
    @IBOutlet var viewPerPDFDocumentButton: UIBarButtonItem!
    @IBOutlet var doneEditingButton: UIBarButtonItem!
    
    //MARK: Actions
    @IBAction func freeHandAnnotate(_ freeHandAnnotateButton: UIBarButtonItem) -> Void {
        self.path = UIBezierPath()
        
        self.pdfView.isUserInteractionEnabled = false
        
        self.ezGraderMode = EZGraderMode.freeHandAnnotate
        
        self.updateNavigationBar()
    }
    
    @IBAction func textAnnotate(_ textAnnotateButton: UIBarButtonItem) -> Void {
        self.pdfView.isUserInteractionEnabled = false
        
        self.ezGraderMode = EZGraderMode.textAnnotate
        
        self.updateNavigationBar()
    }
    
    @IBAction func addGrade(_ addGradeButton: UIBarButtonItem) -> Void {
        self.pdfView.isUserInteractionEnabled = false
        
        self.ezGraderMode = EZGraderMode.addGrade
        
        self.updateNavigationBar()
    }
    
    @IBAction func save(_ saveButton: UIBarButtonItem) -> Void {
        self.startActivityIndicator()
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            let documentsPath: String = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
            
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
            
            DispatchQueue.main.async {
                self.stopActivityIndicator()
            }
        }
    }
    
    @IBAction func viewPerPDFPage(_ viewPerPDFPageButton: UIBarButtonItem) -> Void {
        if self.isPerPDFPageMode == true {
            return
        }
        
        self.startActivityIndicator()
        
        self.isPerPDFPageMode = true
        
        self.viewPerPDFPageButton.tintColor = UIColor.red
        self.viewPerPDFDocumentButton.tintColor = self.appDefaultButtonTintColor
        
        let currentPDFPage: PDFPage = self.pdfView.currentPage!
        
        let perPDFPageCombinedPDFDocument = PDFDocument()
        
        let numberOfPDFDocuments: Int = self.combinedPDFDocument.pageCount / self.numberOfPagesPerPDFDocument
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            for pdfDocumentPageIndex: Int in 0...self.numberOfPagesPerPDFDocument - 1 {
                for pdfDocumentIndex: Int in 0...numberOfPDFDocuments - 1 {
                    perPDFPageCombinedPDFDocument.insert(self.combinedPDFDocument.page(at: pdfDocumentIndex * self.numberOfPagesPerPDFDocument + pdfDocumentPageIndex)!, at: perPDFPageCombinedPDFDocument.pageCount)
                }
            }
            
            DispatchQueue.main.async {
                self.stopActivityIndicator()
                
                self.combinedPDFDocument = perPDFPageCombinedPDFDocument
                
                self.pdfView.document = self.combinedPDFDocument
                
                self.pdfView.go(to: currentPDFPage)
            }
        }
    }
    
    @IBAction func viewPerPDFDocument(_ viewPerPDFDocumentButton: UIBarButtonItem) -> Void {
        if self.isPerPDFPageMode == false {
            return
        }
        
        self.startActivityIndicator()
        
        self.isPerPDFPageMode = false
        
        self.viewPerPDFPageButton.tintColor = self.appDefaultButtonTintColor
        self.viewPerPDFDocumentButton.tintColor = UIColor.red
        
        let currentPDFPage: PDFPage = self.pdfView.currentPage!
        
        let perPDFDocumentCombinedPDFDocument = PDFDocument()
        
        let numberOfPDFDocuments: Int = self.combinedPDFDocument.pageCount / self.numberOfPagesPerPDFDocument
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            for pdfDocumentIndex: Int in 0...numberOfPDFDocuments - 1 {
                for pdfDocumentPageIndex: Int in 0...self.numberOfPagesPerPDFDocument - 1 {
                    perPDFDocumentCombinedPDFDocument.insert(self.combinedPDFDocument.page(at: pdfDocumentPageIndex * numberOfPDFDocuments + pdfDocumentIndex)!, at: perPDFDocumentCombinedPDFDocument.pageCount)
                }
            }
            
            DispatchQueue.main.async {
                self.stopActivityIndicator()
                
                self.combinedPDFDocument = perPDFDocumentCombinedPDFDocument
                
                self.pdfView.document = self.combinedPDFDocument
                
                self.pdfView.go(to: currentPDFPage)
            }
        }
    }
    
    @IBAction func doneEditing(_ doneEditingButton: UIBarButtonItem) -> Void {
        if self.ezGraderMode == EZGraderMode.freeHandAnnotate {
            self.currentFreeHandPDFAnnotation = nil
            self.currentFreeHandPDFAnnotationPDFPage = nil
            self.leftCurrentPageWhenFreeHandAnnotating = false
        }
        
        self.pdfView.isUserInteractionEnabled = true
        
        self.ezGraderMode = EZGraderMode.viewPDFDocuments
        
        self.updateNavigationBar()
    }
    
    @IBAction func tap(_ uiTapGestureRecognizer: UITapGestureRecognizer) -> Void {
        if self.ezGraderMode == EZGraderMode.viewPDFDocuments {
            if uiTapGestureRecognizer.state == UIGestureRecognizerState.recognized {
                let tapViewCoordinate: CGPoint = uiTapGestureRecognizer.location(in: self.pdfView)
                let pdfPageAtTappedPosition: PDFPage = self.pdfView.page(for: tapViewCoordinate, nearest: true)!
                let tapPDFPageCoordinate: CGPoint = self.pdfView.convert(tapViewCoordinate, to: pdfPageAtTappedPosition)
                
                //Filter annotations on the page to only return tapped freetext PDF annotations
                let tappedFreeTextPDFAnnotations: [PDFAnnotation] = pdfPageAtTappedPosition.annotations.filter({ (pdfAnnotation: PDFAnnotation) -> Bool in
                    return pdfAnnotation.type! == PDFAnnotationSubtype.freeText.rawValue.replacingOccurrences(of: "/", with: "") && pdfAnnotation.bounds.contains(tapPDFPageCoordinate)
                })
                
                if tappedFreeTextPDFAnnotations.count > 0 {
                    let topTappedFreeTextPDFAnnotation: PDFAnnotation = tappedFreeTextPDFAnnotations[tappedFreeTextPDFAnnotations.count - 1]
                
                    if topTappedFreeTextPDFAnnotation.annotationKeyValues[PDFAnnotationKey.widgetCaption] as? String == "Text Annotation" {
                        self.showEditTextAnnotationInputDialog(textAnnotationToEdit: topTappedFreeTextPDFAnnotation)
                    } else {
                        self.showEditGradeInputDialog(gradeAnnotationToEdit: topTappedFreeTextPDFAnnotation)
                    }
                }
            }
        }
    }
    
    override func viewDidLoad() -> Void {
        super.viewDidLoad()
        
        self.startActivityIndicator()
        
        let pdfDocumentURLs: [URL] = Bundle.main.urls(forResourcesWithExtension: "pdf", subdirectory: nil)!
        
        for pdfDocumentURL: URL in pdfDocumentURLs {
            self.pdfDocumentFileNames.append(pdfDocumentURL.deletingPathExtension().lastPathComponent)

            if self.numberOfPagesPerPDFDocument == nil {
                self.numberOfPagesPerPDFDocument = PDFDocument(url: pdfDocumentURL)!.pageCount
            }
        }
        
        self.isPerPDFPageMode = true
        self.combinedPDFDocument = PDFDocument()
        
        self.pdfView.displayMode = PDFDisplayMode.singlePageContinuous
        self.pdfView.autoScales = true
        self.pdfView.frame = self.view.bounds
        self.pdfView.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight]
        self.pdfView.isUserInteractionEnabled = true
        
        self.overlayView.frame = self.view.bounds
        self.overlayView.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight]
        
        self.ezGraderMode = EZGraderMode.viewPDFDocuments
        
        self.appDefaultButtonTintColor = self.viewPerPDFPageButton.tintColor
        self.viewPerPDFPageButton.tintColor = UIColor.red
        
        self.leftCurrentPageWhenFreeHandAnnotating = false
        
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
        self.updateNavigationBar()
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            for pdfDocumentPageIndex: Int in 0...self.numberOfPagesPerPDFDocument - 1 {
                for pdfDocumentURL: URL in pdfDocumentURLs {
                    let pdfPage: PDFPage = (PDFDocument(url: pdfDocumentURL)!.page(at: pdfDocumentPageIndex))!
                    
                    self.combinedPDFDocument.insert(pdfPage, at: self.combinedPDFDocument.pageCount)
                }
            }
            
            DispatchQueue.main.async {
                self.stopActivityIndicator()
                
                self.pdfView.document = self.combinedPDFDocument
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) -> Void {
        if self.ezGraderMode == EZGraderMode.freeHandAnnotate || self.ezGraderMode == EZGraderMode.textAnnotate || self.ezGraderMode == EZGraderMode.addGrade {
            if let touch: UITouch = touches.first {
                let touchViewCoordinate: CGPoint = touch.location(in: self.pdfView)
                let pdfPageAtTouchedPosition: PDFPage = self.pdfView.page(for: touchViewCoordinate, nearest: true)!
                let pdfDocumentPageIndexAtTouchedPosition: Int = (self.pdfView.document?.index(for: pdfPageAtTouchedPosition))!
                let touchPDFPageCoordinate: CGPoint = self.pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
                
                if self.ezGraderMode == EZGraderMode.freeHandAnnotate {
                    if self.currentFreeHandPDFAnnotationPDFPage == nil {
                        self.currentFreeHandPDFAnnotationPDFPage = pdfPageAtTouchedPosition
                    }
                    
                    if pdfPageAtTouchedPosition == self.currentFreeHandPDFAnnotationPDFPage {
                        self.path.move(to: touchPDFPageCoordinate)

                        self.isDot = true
                    }
                } else if self.ezGraderMode == EZGraderMode.textAnnotate {
                    self.showAddTextAnnotationInputDialog(touchPDFPageCoordinate: touchPDFPageCoordinate, pdfDocumentPageIndexAtTouchedPosition: pdfDocumentPageIndexAtTouchedPosition)
                } else if self.ezGraderMode == EZGraderMode.addGrade {
                    self.showAddGradeInputDialog(touchPDFPageCoordinate: touchPDFPageCoordinate, pdfDocumentPageIndexAtTouchedPosition: pdfDocumentPageIndexAtTouchedPosition)
                }
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) -> Void {
        if self.ezGraderMode == EZGraderMode.freeHandAnnotate {
            if let touch: UITouch = touches.first {
                let touchViewCoordinate: CGPoint = touch.location(in: self.pdfView)
                let pdfPageAtTouchedPosition: PDFPage = self.pdfView.page(for: touchViewCoordinate, nearest: true)!
                
                if pdfPageAtTouchedPosition == self.currentFreeHandPDFAnnotationPDFPage {
                    let pdfDocumentPageIndexAtTouchedPosition: Int = (self.pdfView.document?.index(for: pdfPageAtTouchedPosition))!
                    let touchPDFPageCoordinate: CGPoint = self.pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
                    
                    if !self.leftCurrentPageWhenFreeHandAnnotating {
                        self.path.addLine(to: touchPDFPageCoordinate)
                        
                        self.isDot = false
                    } else {
                        self.path.move(to: touchPDFPageCoordinate)
                        
                        self.isDot = true
                        
                        self.leftCurrentPageWhenFreeHandAnnotating = false
                    }
                    
                    if self.currentFreeHandPDFAnnotation != nil {
                        self.pdfView.document?.page(at: pdfDocumentPageIndexAtTouchedPosition)?.removeAnnotation(self.currentFreeHandPDFAnnotation)
                    }
                    
                    let currentAnnotationPDFBorder: PDFBorder = PDFBorder()
                    
                    currentAnnotationPDFBorder.lineWidth = 2.0
                    
                    self.currentFreeHandPDFAnnotation = PDFAnnotation(bounds: pdfPageAtTouchedPosition.bounds(for: PDFDisplayBox.cropBox), forType: PDFAnnotationSubtype.ink, withProperties: nil)
                    self.currentFreeHandPDFAnnotation.color = UIColor.red
                    self.currentFreeHandPDFAnnotation.add(self.path)
                    self.currentFreeHandPDFAnnotation.border = currentAnnotationPDFBorder
                    
                    self.pdfView.document?.page(at: pdfDocumentPageIndexAtTouchedPosition)?.addAnnotation(self.currentFreeHandPDFAnnotation)
                } else {
                    self.leftCurrentPageWhenFreeHandAnnotating = true
                    
                    self.isDot = false
                }
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) -> Void {
        if self.ezGraderMode == EZGraderMode.freeHandAnnotate && self.isDot {
            if let touch: UITouch = touches.first {
                let touchViewCoordinate: CGPoint = touch.location(in: self.pdfView)
                let pdfPageAtTouchedPosition: PDFPage = self.pdfView.page(for: touchViewCoordinate, nearest: true)!
                
                if pdfPageAtTouchedPosition == self.currentFreeHandPDFAnnotationPDFPage {
                    let touchPDFPageCoordinate: CGPoint = self.pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
                    let pdfDocumentPageIndexAtTouchedPosition: Int = (self.pdfView.document?.index(for: pdfPageAtTouchedPosition))!
                    
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
                    self.currentFreeHandPDFAnnotation.color = UIColor.red
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
        var maximumPointsRunningTotal: Double
        var pdfDocumentPageQuestionPointsEarned: String
        
        var csvFileContentsString: String = "-,-"
        
        for pdfDocumentFileName: String in self.pdfDocumentFileNames {
            csvFileContentsString += ",\"\(pdfDocumentFileName)\""
        }
        
        csvFileContentsString += "\n"
        
        if grades.keys.count == 0 {
            csvFileContentsString += "No grades have been entered yet.\n"
        } else {
            csvFileContentsString += "MAX POINTS,-"
            
            let pdfDocumentPageNumbersHavingGradesSorted: [Int] = grades[self.pdfDocumentFileNames[0]]!.keys.sorted(by: { (pdfDocumentPage1Number: Int, pdfDocumentPage2Number: Int) -> Bool in
                return pdfDocumentPage1Number < pdfDocumentPage2Number
            })
            
            for pdfDocumentFileName: String in self.pdfDocumentFileNames {
                maximumPointsRunningTotal = 0
                
                for pdfDocumentPageNumberHavingGrades: Int in pdfDocumentPageNumbersHavingGradesSorted {
                    for grade: String in grades[pdfDocumentFileName]![pdfDocumentPageNumberHavingGrades]! {
                        maximumPointsRunningTotal += Double(grade.components(separatedBy: "/").map({ (gradeComponent: String) -> String in
                            return gradeComponent.trimmingCharacters(in: CharacterSet.whitespaces)
                        })[1])!
                    }
                }

                csvFileContentsString += ",\"\(maximumPointsRunningTotal)\""
            }
            
            csvFileContentsString += "\n"
            
            for pdfDocumentPageNumberHavingGrades: Int in pdfDocumentPageNumbersHavingGradesSorted {
                for pdfDocumentPageQuestionNumber: Int in 1...(grades[self.pdfDocumentFileNames[0]]![pdfDocumentPageNumberHavingGrades]?.count)! {
                    if pdfDocumentPageQuestionNumber == 1 {
                        csvFileContentsString += "\"Page \(pdfDocumentPageNumberHavingGrades)\""
                    }
                    
                    csvFileContentsString += ",\"Question \(pdfDocumentPageQuestionNumber)\""
                    
                    for pdfDocumentFileName: String in self.pdfDocumentFileNames {
                        pdfDocumentPageQuestionPointsEarned = grades[pdfDocumentFileName]![pdfDocumentPageNumberHavingGrades]![pdfDocumentPageQuestionNumber - 1].components(separatedBy: "/").map({ (gradeComponent: String) -> String in
                            return gradeComponent.trimmingCharacters(in: CharacterSet.whitespaces)
                        })[0]
                        
                        csvFileContentsString += ",\"\(pdfDocumentPageQuestionPointsEarned)\""
                    }
                    
                    csvFileContentsString += "\n"
                }
            }
        }
        
        let fileManager: FileManager = FileManager.default
        
        do {
            let gradesFileURL: URL = try fileManager.url(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.allDomainsMask, appropriateFor: nil, create: false)
            
            try csvFileContentsString.write(to: gradesFileURL.appendingPathComponent("Grades.csv"), atomically: true, encoding: String.Encoding.utf8)
        } catch {
            // create the alert
            let failedToSaveGradesCSVFileUIAlertController: UIAlertController = UIAlertController(title: "Error", message: "Failed to save Grades.csv file.", preferredStyle: UIAlertControllerStyle.alert)
            
            // add the actions (buttons)
            failedToSaveGradesCSVFileUIAlertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            
            // show the alert
            self.present(failedToSaveGradesCSVFileUIAlertController, animated: true, completion: nil)
        }
    }
    
    private func showAddTextAnnotationInputDialog(touchPDFPageCoordinate: CGPoint, pdfDocumentPageIndexAtTouchedPosition: Int) -> Void {
        let addTextAnnotationUIAlertController = UIAlertController(title: "Add Text Annotation", message: "", preferredStyle: UIAlertControllerStyle.alert)
        
        let addTextAnnotationUIAlertAction: UIAlertAction = UIAlertAction(title: "Submit", style: UIAlertActionStyle.default) { (alert: UIAlertAction!) in
            let enteredText: String = (addTextAnnotationUIAlertController.textFields?[0].text)!
            let enteredTextSize: CGSize = self.getTextSize(text: enteredText + "  ")
            
            let textAnnotationFreeTextPDFAnnotation: PDFAnnotation = PDFAnnotation(bounds: CGRect(origin: touchPDFPageCoordinate, size: CGSize(width: enteredTextSize.height, height: enteredTextSize.width)), forType: PDFAnnotationSubtype.freeText, withProperties: nil)
            
            textAnnotationFreeTextPDFAnnotation.fontColor = UIColor.red
            textAnnotationFreeTextPDFAnnotation.font = UIFont.systemFont(ofSize: self.appFontSize)
            textAnnotationFreeTextPDFAnnotation.color = UIColor.clear
            textAnnotationFreeTextPDFAnnotation.isReadOnly = true
            textAnnotationFreeTextPDFAnnotation.contents = enteredText
            textAnnotationFreeTextPDFAnnotation.setValue("Text Annotation", forAnnotationKey: PDFAnnotationKey.widgetCaption)
            
            self.pdfView.document?.page(at: pdfDocumentPageIndexAtTouchedPosition)?.addAnnotation(textAnnotationFreeTextPDFAnnotation)
        }
        
        let cancelAddTextAnnotationUIAlertAction: UIAlertAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (alert: UIAlertAction!) in }
        
        addTextAnnotationUIAlertController.addTextField { (textAnnotationTextField: UITextField) in
            textAnnotationTextField.placeholder = "Text Annotation"
        }
        
        addTextAnnotationUIAlertController.addAction(addTextAnnotationUIAlertAction)
        addTextAnnotationUIAlertController.addAction(cancelAddTextAnnotationUIAlertAction)
        
        self.present(addTextAnnotationUIAlertController, animated: true, completion: nil)
    }
    
    private func showEditTextAnnotationInputDialog(textAnnotationToEdit: PDFAnnotation) -> Void {
        let editTextAnnotationUIAlertController = UIAlertController(title: "Edit Text Annotation", message: "", preferredStyle: UIAlertControllerStyle.alert)
        
        let editTextAnnotationUIAlertAction: UIAlertAction = UIAlertAction(title: "Submit", style: UIAlertActionStyle.default) { (alert: UIAlertAction!) in
            let enteredText: String = (editTextAnnotationUIAlertController.textFields?[0].text)!
            let enteredTextSize: CGSize = self.getTextSize(text: enteredText + "  ")
            
            textAnnotationToEdit.bounds.size = CGSize(width: enteredTextSize.height, height: enteredTextSize.width)
            textAnnotationToEdit.contents = enteredText
        }
        
        let cancelEditTextAnnotationUIAlertAction: UIAlertAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (alert: UIAlertAction!) in }
        
        editTextAnnotationUIAlertController.addTextField { (textAnnotationTextField: UITextField) in
            textAnnotationTextField.placeholder = "Text Annotation"
            textAnnotationTextField.text = textAnnotationToEdit.contents
        }
        
        editTextAnnotationUIAlertController.addAction(editTextAnnotationUIAlertAction)
        editTextAnnotationUIAlertController.addAction(cancelEditTextAnnotationUIAlertAction)
        
        self.present(editTextAnnotationUIAlertController, animated: true, completion: nil)
    }
    
    private func showAddGradeInputDialog(touchPDFPageCoordinate: CGPoint, pdfDocumentPageIndexAtTouchedPosition: Int) -> Void {
        let addGradeUIAlertController = UIAlertController(title: "Add Grade", message: "", preferredStyle: UIAlertControllerStyle.alert)
        
        let addGradeUIAlertAction: UIAlertAction = UIAlertAction(title: "Submit", style: UIAlertActionStyle.default) { (alert: UIAlertAction!) in
            self.addGradeToAllPDFDocuments(pointsEarned: (addGradeUIAlertController.textFields?[0].text)!, maximumPoints: (addGradeUIAlertController.textFields?[1].text)!, touchPDFPageCoordinate: touchPDFPageCoordinate, pdfDocumentPageIndexAtTouchedPosition: pdfDocumentPageIndexAtTouchedPosition)
        }
        
        let cancelAddGradeUIAlertAction: UIAlertAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (alert: UIAlertAction!) in }
        
        addGradeUIAlertController.addTextField { (pointsEarnedTextField: UITextField) in
            pointsEarnedTextField.placeholder = "Points Earned"
            pointsEarnedTextField.keyboardType = UIKeyboardType.decimalPad
        }
        
        addGradeUIAlertController.addTextField { (maximumPointsTextField: UITextField) in
            maximumPointsTextField.placeholder = "Maximum Points"
            maximumPointsTextField.keyboardType = UIKeyboardType.decimalPad
        }
        
        addGradeUIAlertController.addAction(addGradeUIAlertAction)
        addGradeUIAlertController.addAction(cancelAddGradeUIAlertAction)
        
        self.present(addGradeUIAlertController, animated: true, completion: nil)
    }
    
    private func showEditGradeInputDialog(gradeAnnotationToEdit: PDFAnnotation) -> Void {
        let editGradeUIAlertController = UIAlertController(title: "Edit Grade", message: "", preferredStyle: UIAlertControllerStyle.alert)
        
        let editGradeUIAlertAction: UIAlertAction = UIAlertAction(title: "Submit", style: UIAlertActionStyle.default) { (alert: UIAlertAction!) in
            let gradeText: String = (editGradeUIAlertController.textFields?[0].text)! + " / " + (editGradeUIAlertController.textFields?[1].text)!
            let gradeTextSize: CGSize = self.getTextSize(text: gradeText + "  ")
            
            gradeAnnotationToEdit.bounds.size = CGSize(width: gradeTextSize.height, height: gradeTextSize.width)
            gradeAnnotationToEdit.contents = gradeText
        }
        
        let cancelEditGradeUIAlertAction: UIAlertAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (alert: UIAlertAction!) in }
        
        let gradeComponents: [String] = gradeAnnotationToEdit.contents!.components(separatedBy: "/").map({ (gradeComponent: String) -> String in
            return gradeComponent.trimmingCharacters(in: CharacterSet.whitespaces)
        })
        
        editGradeUIAlertController.addTextField { (pointsEarnedTextField: UITextField) in
            pointsEarnedTextField.placeholder = "Points Earned"
            pointsEarnedTextField.keyboardType = UIKeyboardType.decimalPad
            pointsEarnedTextField.text = gradeComponents[0]
        }
        
        editGradeUIAlertController.addTextField { (maximumPointsTextField: UITextField) in
            maximumPointsTextField.placeholder = "Maximum Points"
            maximumPointsTextField.keyboardType = UIKeyboardType.decimalPad
            maximumPointsTextField.isEnabled = false
            maximumPointsTextField.textColor = UIColor.gray
            maximumPointsTextField.text = gradeComponents[1]
        }
        
        editGradeUIAlertController.addAction(editGradeUIAlertAction)
        editGradeUIAlertController.addAction(cancelEditGradeUIAlertAction)
        
        self.present(editGradeUIAlertController, animated: true, completion: nil)
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
        
        let gradeFreeTextPDFAnnotation: PDFAnnotation = PDFAnnotation(bounds: CGRect(origin: touchPDFPageCoordinate, size: CGSize(width: gradeTextSize.height, height: gradeTextSize.width)), forType: PDFAnnotationSubtype.freeText, withProperties: nil)
        
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
    
    private func startActivityIndicator() -> Void {
        if !self.uiActivityIndicatorView.isAnimating {
            self.overlayView.backgroundColor = UIColor.clear.withAlphaComponent(0.4)
            
            UIApplication.shared.beginIgnoringInteractionEvents()
            
            self.uiActivityIndicatorView.startAnimating()
        }
    }
    
    private func stopActivityIndicator() -> Void {
        if self.uiActivityIndicatorView.isAnimating {
            self.overlayView.backgroundColor = UIColor.clear
            
            self.uiActivityIndicatorView.stopAnimating()
            
            UIApplication.shared.endIgnoringInteractionEvents()
        }
    }
    
    private func updateNavigationBar() -> Void {
        switch self.ezGraderMode {
        case EZGraderMode.viewPDFDocuments?:
            self.navigationItem.leftBarButtonItems = [self.freeHandAnnotateButton, self.textAnnotateButton, self.addGradeButton, self.saveButton]
            self.navigationItem.rightBarButtonItems = [self.viewPerPDFDocumentButton, self.viewPerPDFPageButton]
            self.navigationItem.hidesBackButton = false
            self.navigationItem.title = ""
        case EZGraderMode.freeHandAnnotate?,
             EZGraderMode.textAnnotate?,
             EZGraderMode.addGrade?:
            self.navigationItem.leftBarButtonItems = []
            self.navigationItem.rightBarButtonItems = [self.doneEditingButton]
            self.navigationItem.hidesBackButton = true
            
            switch self.ezGraderMode {
            case EZGraderMode.freeHandAnnotate?,
                 EZGraderMode.textAnnotate?:
                self.navigationItem.title = "Annotating"
            case EZGraderMode.addGrade?:
                self.navigationItem.title = "Adding Grades"
            default:
                break
            }
        default:
            break
        }
    }
}
