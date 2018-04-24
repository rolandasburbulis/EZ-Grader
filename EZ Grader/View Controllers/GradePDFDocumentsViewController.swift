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
    case eraseFreeHandAnnotation
    case textAnnotate
    case addGrade
}

class GradePDFDocumentsViewController: UIViewController, UIGestureRecognizerDelegate {
    let appFontSize: CGFloat = 30
    
    var ezGraderMode: EZGraderMode?
    var currentFreeHandPDFAnnotationBezierPath: UIBezierPath!
    var currentFreeHandPDFAnnotation: PDFAnnotation!
    var currentFreeHandPDFAnnotationPDFPage: PDFPage!
    var leftCurrentPageWhenFreeHandAnnotating: Bool!
    var numberOfPagesPerPDFDocument: Int!
    var combinedPDFDocument: PDFDocument!
    var isPerPDFPageMode: Bool!
    var isDot: Bool!
    var appDefaultButtonTintColor: UIColor!
    var pdfDocumentURLs: [URL] = []
    var pdfDocumentFileNames: [String] = []
    
    //MARK: Properties
    @IBOutlet weak var pdfView: PDFView!
    @IBOutlet var overlayView: UIView!
    @IBOutlet var uiActivityIndicatorView: UIActivityIndicatorView!
    @IBOutlet var backButton: UIBarButtonItem!
    @IBOutlet var freeHandAnnotateButton: UIBarButtonItem!
    @IBOutlet var eraseFreeHandAnnotationButton: UIBarButtonItem!
    @IBOutlet var textAnnotateButton: UIBarButtonItem!
    @IBOutlet var addGradeButton: UIBarButtonItem!
    @IBOutlet var saveButton: UIBarButtonItem!
    @IBOutlet var viewPerPDFPageButton: UIBarButtonItem!
    @IBOutlet var viewPerPDFDocumentButton: UIBarButtonItem!
    @IBOutlet var doneEditingButton: UIBarButtonItem!
    
    //MARK: Actions
    @IBAction func back(_ backButton: UIBarButtonItem) {
        let confirmGoBackUIAlertController: UIAlertController = UIAlertController(title: "Leave Assignment?", message: "Are you sure you want to leave this assignment?  All changes made since assignment was last saved will be lost.", preferredStyle: UIAlertControllerStyle.alert)
        
        let confirmGoBackUIAlertAction: UIAlertAction = UIAlertAction(title: "Yes", style: UIAlertActionStyle.destructive) { (alert: UIAlertAction!) in
            self.navigationController?.popViewController(animated: true)
        }
        
        let cancelGoBackUIAlertAction: UIAlertAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (alert: UIAlertAction!) in }
        
        confirmGoBackUIAlertController.addAction(confirmGoBackUIAlertAction)
        confirmGoBackUIAlertController.addAction(cancelGoBackUIAlertAction)
        
        self.present(confirmGoBackUIAlertController, animated: true, completion: nil)
    }
    
    @IBAction func freeHandAnnotate(_ freeHandAnnotateButton: UIBarButtonItem) -> Void {
        self.currentFreeHandPDFAnnotationBezierPath = UIBezierPath()
        
        self.pdfView.isUserInteractionEnabled = false
        
        self.ezGraderMode = EZGraderMode.freeHandAnnotate
        
        self.updateNavigationBar()
    }
    
    @IBAction func eraseFreeHandAnnotation(_ eraseFreeHandAnnotationButton: UIBarButtonItem) -> Void {
        self.ezGraderMode = EZGraderMode.eraseFreeHandAnnotation
        
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
        if self.ezGraderMode == EZGraderMode.viewPDFDocuments || self.ezGraderMode == EZGraderMode.eraseFreeHandAnnotation {
            if uiTapGestureRecognizer.state == UIGestureRecognizerState.recognized {
                let tapViewCoordinate: CGPoint = uiTapGestureRecognizer.location(in: self.pdfView)
                let pdfPageAtTappedPosition: PDFPage = self.pdfView.page(for: tapViewCoordinate, nearest: true)!
                let tapPDFPageCoordinate: CGPoint = self.pdfView.convert(tapViewCoordinate, to: pdfPageAtTappedPosition)
                
                if self.ezGraderMode == EZGraderMode.viewPDFDocuments {
                    //Filter annotations on the page to only return tapped freetext PDF annotations
                    let tappedFreeTextPDFAnnotations: [PDFAnnotation] = pdfPageAtTappedPosition.annotations.filter({ (pdfAnnotation: PDFAnnotation) -> Bool in
                        return pdfAnnotation.type! == PDFAnnotationSubtype.freeText.rawValue.replacingOccurrences(of: "/", with: "") && pdfAnnotation.bounds.contains(tapPDFPageCoordinate)
                    })
                    
                    if tappedFreeTextPDFAnnotations.count > 0 {
                        let topTappedFreeTextPDFAnnotation: PDFAnnotation = tappedFreeTextPDFAnnotations[tappedFreeTextPDFAnnotations.count - 1]
                    
                        if topTappedFreeTextPDFAnnotation.annotationKeyValues[PDFAnnotationKey.widgetCaption] as? String == "Text Annotation" {
                            self.showEditRemoveTextAnnotationDialog(tappedTextAnnotation: topTappedFreeTextPDFAnnotation)
                        } else {
                            self.showEditRemoveGradeDialog(tappedGradeAnnotation: topTappedFreeTextPDFAnnotation)
                        }
                    }
                } else {
                    //Filter annotations on the page to only return tapped ink PDF annotations
                    let tappedInkPDFAnnotations: [PDFAnnotation] = pdfPageAtTappedPosition.annotations.filter({ (pdfAnnotation: PDFAnnotation) -> Bool in
                        return pdfAnnotation.type! == PDFAnnotationSubtype.ink.rawValue.replacingOccurrences(of: "/", with: "") && pdfAnnotation.paths![0].bounds.contains(tapPDFPageCoordinate)
                    })
                    
                    if tappedInkPDFAnnotations.count > 0 {
                        pdfPageAtTappedPosition.removeAnnotation(tappedInkPDFAnnotations[tappedInkPDFAnnotations.count - 1])
                    }
                }
            }
        }
    }
    
    override func viewDidLoad() -> Void {
        super.viewDidLoad()
        
        self.startActivityIndicator()
        
        for pdfDocumentURL: URL in self.pdfDocumentURLs {
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
        self.navigationItem.hidesBackButton = true
        
        self.updateNavigationBar()
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            for pdfDocumentPageIndex: Int in 0...self.numberOfPagesPerPDFDocument - 1 {
                for pdfDocumentURL: URL in self.pdfDocumentURLs {
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
                let touchPDFPageCoordinate: CGPoint = self.pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
                let pdfDocumentPageIndexAtTouchedPosition: Int = self.combinedPDFDocument.index(for: pdfPageAtTouchedPosition)
                
                if self.ezGraderMode == EZGraderMode.freeHandAnnotate {
                    if self.currentFreeHandPDFAnnotationPDFPage == nil {
                        self.currentFreeHandPDFAnnotationPDFPage = pdfPageAtTouchedPosition
                    }
                    
                    if pdfPageAtTouchedPosition == self.currentFreeHandPDFAnnotationPDFPage {
                        self.currentFreeHandPDFAnnotationBezierPath.move(to: touchPDFPageCoordinate)

                        self.isDot = true
                    }
                } else if self.ezGraderMode == EZGraderMode.textAnnotate {
                    self.showAddTextAnnotationDialog(touchPDFPageCoordinate: touchPDFPageCoordinate, pdfDocumentPageIndexAtTouchedPosition: pdfDocumentPageIndexAtTouchedPosition)
                } else if self.ezGraderMode == EZGraderMode.addGrade {
                    self.showAddGradeDialog(touchPDFPageCoordinate: touchPDFPageCoordinate, pdfDocumentPageIndexAtTouchedPosition: pdfDocumentPageIndexAtTouchedPosition)
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
                    let touchPDFPageCoordinate: CGPoint = self.pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
                    
                    if !self.leftCurrentPageWhenFreeHandAnnotating {
                        self.currentFreeHandPDFAnnotationBezierPath.addLine(to: touchPDFPageCoordinate)
                        
                        self.isDot = false
                    } else {
                        self.currentFreeHandPDFAnnotationBezierPath.move(to: touchPDFPageCoordinate)
                        
                        self.isDot = true
                        
                        self.leftCurrentPageWhenFreeHandAnnotating = false
                    }
                    
                    self.updateFreeHandPDFAnnotationInPDFDocument(pdfPageAtTouchedPosition: pdfPageAtTouchedPosition)
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
                    
                    self.currentFreeHandPDFAnnotationBezierPath.addLine(to: CGPoint(x: touchPDFPageCoordinate.x + 1, y: touchPDFPageCoordinate.y))
                    self.currentFreeHandPDFAnnotationBezierPath.addLine(to: CGPoint(x: touchPDFPageCoordinate.x + 1, y: touchPDFPageCoordinate.y + 1))
                    self.currentFreeHandPDFAnnotationBezierPath.addLine(to: CGPoint(x: touchPDFPageCoordinate.x, y: touchPDFPageCoordinate.y + 1))
                    self.currentFreeHandPDFAnnotationBezierPath.addLine(to: touchPDFPageCoordinate)
                    
                    self.updateFreeHandPDFAnnotationInPDFDocument(pdfPageAtTouchedPosition: pdfPageAtTouchedPosition)
                }
            }
        }
    }
    
    private func updateFreeHandPDFAnnotationInPDFDocument(pdfPageAtTouchedPosition: PDFPage) -> Void {
        let pdfDocumentPageIndexAtTouchedPosition = self.combinedPDFDocument.index(for: pdfPageAtTouchedPosition)
        
        if self.currentFreeHandPDFAnnotation != nil {
            self.combinedPDFDocument.page(at: pdfDocumentPageIndexAtTouchedPosition)?.removeAnnotation(self.currentFreeHandPDFAnnotation)
        }
    
        let currentAnnotationPDFBorder: PDFBorder = PDFBorder()
    
        currentAnnotationPDFBorder.lineWidth = 2.0
    
        self.currentFreeHandPDFAnnotation = PDFAnnotation(bounds: pdfPageAtTouchedPosition.bounds(for: PDFDisplayBox.cropBox), forType: PDFAnnotationSubtype.ink, withProperties: nil)
        self.currentFreeHandPDFAnnotation.color = UIColor.red
        self.currentFreeHandPDFAnnotation.add(self.currentFreeHandPDFAnnotationBezierPath)
        self.currentFreeHandPDFAnnotation.border = currentAnnotationPDFBorder
    
        self.combinedPDFDocument.page(at: pdfDocumentPageIndexAtTouchedPosition)?.addAnnotation(self.currentFreeHandPDFAnnotation)
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
        var csvFileContentsString: String = "Page Number,Question Number,Max Question Points"
        
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
        
            var pdfDocumentPageQuestionMaximumPoints: String
            var pdfDocumentPageQuestionPointsEarned: String

            for pdfDocumentPageNumberHavingGrades: Int in pdfDocumentPageNumbersHavingGradesSorted {
                for pdfDocumentPageQuestionNumber: Int in 1...(grades[self.pdfDocumentFileNames[0]]![pdfDocumentPageNumberHavingGrades]?.count)! {
                    if pdfDocumentPageQuestionNumber == 1 {
                        csvFileContentsString += "\"Page \(pdfDocumentPageNumberHavingGrades)\""
                    }
                    
                    pdfDocumentPageQuestionMaximumPoints = grades[self.pdfDocumentFileNames[0]]![pdfDocumentPageNumberHavingGrades]![pdfDocumentPageQuestionNumber - 1].components(separatedBy: "/").map({ (gradeComponent: String) -> String in
                        return gradeComponent.trimmingCharacters(in: CharacterSet.whitespaces)
                    })[1]
                    
                    csvFileContentsString += ",\"Question \(pdfDocumentPageQuestionNumber)\",\"\(pdfDocumentPageQuestionMaximumPoints)\""
                    
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
    
    private func showAddTextAnnotationDialog(touchPDFPageCoordinate: CGPoint, pdfDocumentPageIndexAtTouchedPosition: Int) -> Void {
        let addTextAnnotationUIAlertController: UIAlertController = UIAlertController(title: "Add Text Annotation", message: "", preferredStyle: UIAlertControllerStyle.alert)
        
        let addTextAnnotationUIAlertAction: UIAlertAction = UIAlertAction(title: "Add", style: UIAlertActionStyle.default) { (alert: UIAlertAction!) in
            let enteredText: String = (addTextAnnotationUIAlertController.textFields?[0].text)!
            let enteredTextSize: CGSize = self.getTextSize(text: enteredText + "  ")
            
            let textAnnotationFreeTextPDFAnnotation: PDFAnnotation = PDFAnnotation(bounds: CGRect(origin: touchPDFPageCoordinate, size: CGSize(width: enteredTextSize.width, height: enteredTextSize.height)), forType: PDFAnnotationSubtype.freeText, withProperties: nil)
            
            textAnnotationFreeTextPDFAnnotation.fontColor = UIColor.red
            textAnnotationFreeTextPDFAnnotation.font = UIFont.systemFont(ofSize: self.appFontSize)
            textAnnotationFreeTextPDFAnnotation.color = UIColor.clear
            textAnnotationFreeTextPDFAnnotation.isReadOnly = true
            textAnnotationFreeTextPDFAnnotation.contents = enteredText
            textAnnotationFreeTextPDFAnnotation.setValue("Text Annotation", forAnnotationKey: PDFAnnotationKey.widgetCaption)
            
            self.combinedPDFDocument.page(at: pdfDocumentPageIndexAtTouchedPosition)?.addAnnotation(textAnnotationFreeTextPDFAnnotation)
        }
        
        let cancelAddTextAnnotationUIAlertAction: UIAlertAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (alert: UIAlertAction!) in }
        
        addTextAnnotationUIAlertController.addTextField { (textAnnotationTextField: UITextField) in
            textAnnotationTextField.placeholder = "Text Annotation"
        }
        
        addTextAnnotationUIAlertController.addAction(addTextAnnotationUIAlertAction)
        addTextAnnotationUIAlertController.addAction(cancelAddTextAnnotationUIAlertAction)
        
        self.present(addTextAnnotationUIAlertController, animated: true, completion: nil)
    }
    
    private func showEditRemoveTextAnnotationDialog(tappedTextAnnotation: PDFAnnotation) -> Void {
        let editRemoveTextAnnotationUIAlertController: UIAlertController = UIAlertController(title: "Edit/Remove Text Annotation", message: "", preferredStyle: UIAlertControllerStyle.alert)
        
        let editTextAnnotationUIAlertAction: UIAlertAction = UIAlertAction(title: "Edit", style: UIAlertActionStyle.default) { (alert: UIAlertAction!) in
            let editedText: String = (editRemoveTextAnnotationUIAlertController.textFields?[0].text)!
            let editedTextSize: CGSize = self.getTextSize(text: editedText + "  ")
            
            tappedTextAnnotation.bounds.size = CGSize(width: editedTextSize.width, height: editedTextSize.height)
            tappedTextAnnotation.contents = editedText
        }
        
        let removeTextAnnotationUIAlertAction: UIAlertAction = UIAlertAction(title: "Remove", style: UIAlertActionStyle.destructive) { (alert: UIAlertAction!) in
            tappedTextAnnotation.page?.removeAnnotation(tappedTextAnnotation)
        }
        
        let cancelEditTextAnnotationUIAlertAction: UIAlertAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (alert: UIAlertAction!) in }
        
        editRemoveTextAnnotationUIAlertController.addTextField { (textAnnotationTextField: UITextField) in
            textAnnotationTextField.placeholder = "Text Annotation"
            textAnnotationTextField.text = tappedTextAnnotation.contents
        }
        
        editRemoveTextAnnotationUIAlertController.addAction(editTextAnnotationUIAlertAction)
        editRemoveTextAnnotationUIAlertController.addAction(removeTextAnnotationUIAlertAction)
        editRemoveTextAnnotationUIAlertController.addAction(cancelEditTextAnnotationUIAlertAction)
        
        self.present(editRemoveTextAnnotationUIAlertController, animated: true, completion: nil)
    }
    
    private func showAddGradeDialog(touchPDFPageCoordinate: CGPoint, pdfDocumentPageIndexAtTouchedPosition: Int) -> Void {
        let addGradeUIAlertController: UIAlertController = UIAlertController(title: "Add Grade", message: "", preferredStyle: UIAlertControllerStyle.alert)
        
        let addGradeUIAlertAction: UIAlertAction = UIAlertAction(title: "Add", style: UIAlertActionStyle.default) { (alert: UIAlertAction!) in
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
    
    private func showEditRemoveGradeDialog(tappedGradeAnnotation: PDFAnnotation) -> Void {
        let editRemoveGradeUIAlertController: UIAlertController = UIAlertController(title: "Edit/Remove Grade", message: "", preferredStyle: UIAlertControllerStyle.alert)
        
        let editGradeUIAlertAction: UIAlertAction = UIAlertAction(title: "Edit", style: UIAlertActionStyle.default) { (alert: UIAlertAction!) in
            let editedGradeText: String = (editRemoveGradeUIAlertController.textFields?[0].text)! + " / " + (editRemoveGradeUIAlertController.textFields?[1].text)!
            let editedGradeTextSize: CGSize = self.getTextSize(text: editedGradeText + "  ")
            
            tappedGradeAnnotation.bounds.size = CGSize(width: editedGradeTextSize.width, height: editedGradeTextSize.height)
            tappedGradeAnnotation.contents = editedGradeText
        }
        
        let removeGradeFromAllPDFDocumentsUIAlertAction: UIAlertAction = UIAlertAction(title: "Remove from All", style: UIAlertActionStyle.destructive) { (alert: UIAlertAction!) in
            //Filter annotations on the page to only return grade annotations
            let gradeAnnotations: [PDFAnnotation] = tappedGradeAnnotation.page!.annotations.filter({ (pdfAnnotation: PDFAnnotation) -> Bool in
                return pdfAnnotation.annotationKeyValues[PDFAnnotationKey.widgetCaption] as? String == "Grade Annotation"
            })
            
            self.removeGradeFromAllPDFDocuments(pdfDocumentPageIndexAtTappedPosition: self.combinedPDFDocument.index(for: tappedGradeAnnotation.page!), gradeAnnotationIndex: gradeAnnotations.index(of: tappedGradeAnnotation)!)
        }
        
        let cancelEditGradeUIAlertAction: UIAlertAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (alert: UIAlertAction!) in }
        
        let gradeComponents: [String] = tappedGradeAnnotation.contents!.components(separatedBy: "/").map({ (gradeComponent: String) -> String in
            return gradeComponent.trimmingCharacters(in: CharacterSet.whitespaces)
        })
        
        editRemoveGradeUIAlertController.addTextField { (pointsEarnedTextField: UITextField) in
            pointsEarnedTextField.placeholder = "Points Earned"
            pointsEarnedTextField.keyboardType = UIKeyboardType.decimalPad
            pointsEarnedTextField.text = gradeComponents[0]
        }
        
        editRemoveGradeUIAlertController.addTextField { (maximumPointsTextField: UITextField) in
            maximumPointsTextField.placeholder = "Maximum Points"
            maximumPointsTextField.keyboardType = UIKeyboardType.decimalPad
            maximumPointsTextField.isEnabled = false
            maximumPointsTextField.textColor = UIColor.gray
            maximumPointsTextField.text = gradeComponents[1]
        }
        
        editRemoveGradeUIAlertController.addAction(editGradeUIAlertAction)
        editRemoveGradeUIAlertController.addAction(removeGradeFromAllPDFDocumentsUIAlertAction)
        editRemoveGradeUIAlertController.addAction(cancelEditGradeUIAlertAction)
        
        self.present(editRemoveGradeUIAlertController, animated: true, completion: nil)
    }
    
    private func addGradeToAllPDFDocuments(pointsEarned: String, maximumPoints: String, touchPDFPageCoordinate: CGPoint, pdfDocumentPageIndexAtTouchedPosition: Int) -> Void {
        let gradeForCurrentPDFDocument: String = pointsEarned + " / " + maximumPoints
        let gradeForOtherPDFDocuments: String =  "? / " + maximumPoints
        
        if self.isPerPDFPageMode {
            let numberOfPDFDocuments: Int = self.combinedPDFDocument.pageCount / self.numberOfPagesPerPDFDocument
            let indexOfPDFDocumentPageOfFirstPDFDocument: Int = pdfDocumentPageIndexAtTouchedPosition - (pdfDocumentPageIndexAtTouchedPosition % numberOfPDFDocuments)
            
            for indexOfPDFDocumentPageToAddGradeTo: Int in indexOfPDFDocumentPageOfFirstPDFDocument...indexOfPDFDocumentPageOfFirstPDFDocument + numberOfPDFDocuments - 1 {
                self.combinedPDFDocument.page(at: indexOfPDFDocumentPageToAddGradeTo)?.addAnnotation(createGradeFreeTextAnnotation(gradeText: indexOfPDFDocumentPageToAddGradeTo == pdfDocumentPageIndexAtTouchedPosition ? gradeForCurrentPDFDocument : gradeForOtherPDFDocuments, touchPDFPageCoordinate: touchPDFPageCoordinate))
            }
        } else {
            for indexOfPDFDocumentPageToAddGradeTo: Int in stride(from: pdfDocumentPageIndexAtTouchedPosition % self.numberOfPagesPerPDFDocument, to: self.combinedPDFDocument.pageCount - 1, by: self.numberOfPagesPerPDFDocument) {
                self.combinedPDFDocument.page(at: indexOfPDFDocumentPageToAddGradeTo)?.addAnnotation(createGradeFreeTextAnnotation(gradeText: indexOfPDFDocumentPageToAddGradeTo == pdfDocumentPageIndexAtTouchedPosition ? gradeForCurrentPDFDocument : gradeForOtherPDFDocuments, touchPDFPageCoordinate: touchPDFPageCoordinate))
            }
        }
    }
    
    private func removeGradeFromAllPDFDocuments(pdfDocumentPageIndexAtTappedPosition: Int, gradeAnnotationIndex: Int) -> Void {
        if self.isPerPDFPageMode {
            let numberOfPDFDocuments: Int = self.combinedPDFDocument.pageCount / self.numberOfPagesPerPDFDocument
            let indexOfPDFDocumentPageOfFirstPDFDocument: Int = pdfDocumentPageIndexAtTappedPosition - (pdfDocumentPageIndexAtTappedPosition % numberOfPDFDocuments)
            
            for indexOfPDFDocumentPageToRemoveGradeFrom: Int in indexOfPDFDocumentPageOfFirstPDFDocument...indexOfPDFDocumentPageOfFirstPDFDocument + numberOfPDFDocuments - 1 {
                self.removeGradeFromPDFDocument(indexOfPDFDocumentPageToRemoveGradeFrom: indexOfPDFDocumentPageToRemoveGradeFrom, gradeAnnotationIndex: gradeAnnotationIndex)
            }
        } else {
            for indexOfPDFDocumentPageToRemoveGradeFrom: Int in stride(from: pdfDocumentPageIndexAtTappedPosition % self.numberOfPagesPerPDFDocument, to: self.combinedPDFDocument.pageCount - 1, by: self.numberOfPagesPerPDFDocument) {
                self.removeGradeFromPDFDocument(indexOfPDFDocumentPageToRemoveGradeFrom: indexOfPDFDocumentPageToRemoveGradeFrom, gradeAnnotationIndex: gradeAnnotationIndex)
            }
        }
    }
    
    private func removeGradeFromPDFDocument(indexOfPDFDocumentPageToRemoveGradeFrom: Int, gradeAnnotationIndex: Int) -> Void {
        let gradeAnnotationToRemove: PDFAnnotation = (self.combinedPDFDocument.page(at: indexOfPDFDocumentPageToRemoveGradeFrom)?.annotations.filter({ (pdfAnnotation: PDFAnnotation) -> Bool in
            return pdfAnnotation.annotationKeyValues[PDFAnnotationKey.widgetCaption] as? String == "Grade Annotation"
        })[gradeAnnotationIndex])!
        
        self.combinedPDFDocument.page(at: indexOfPDFDocumentPageToRemoveGradeFrom)?.removeAnnotation(gradeAnnotationToRemove)
    }
    
    private func createGradeFreeTextAnnotation(gradeText: String, touchPDFPageCoordinate: CGPoint) -> PDFAnnotation {
        let gradeTextSize: CGSize = self.getTextSize(text: gradeText + "  ")
        
        let gradeFreeTextPDFAnnotation: PDFAnnotation = PDFAnnotation(bounds: CGRect(origin: touchPDFPageCoordinate, size: CGSize(width: gradeTextSize.width, height: gradeTextSize.height)), forType: PDFAnnotationSubtype.freeText, withProperties: nil)
        
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
            self.navigationItem.leftBarButtonItems = [self.backButton, self.freeHandAnnotateButton, self.eraseFreeHandAnnotationButton, self.textAnnotateButton, self.addGradeButton, self.saveButton]
            self.navigationItem.rightBarButtonItems = [self.viewPerPDFDocumentButton, self.viewPerPDFPageButton]

            self.navigationItem.title = ""
        case EZGraderMode.freeHandAnnotate?,
             EZGraderMode.eraseFreeHandAnnotation?,
             EZGraderMode.textAnnotate?,
             EZGraderMode.addGrade?:
            self.navigationItem.leftBarButtonItems = []
            self.navigationItem.rightBarButtonItems = [self.doneEditingButton]
            
            switch self.ezGraderMode {
            case EZGraderMode.freeHandAnnotate?:
                self.navigationItem.title = "Free-Hand Annotate"
            case EZGraderMode.eraseFreeHandAnnotation?:
                self.navigationItem.title = "Tap Free-Hand Annotation to Erase"
            case EZGraderMode.textAnnotate?:
                self.navigationItem.title = "Tap to Add Text"
            case EZGraderMode.addGrade?:
                self.navigationItem.title = "Tap to Add Grade"
            default:
                break
            }
        default:
            break
        }
    }
}
