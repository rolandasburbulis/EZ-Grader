//
//  ViewController.swift
//  EZ Grader
//
//  Copyright © 2018 RIT. All rights reserved.
//

import PDFKit

enum EZGraderMode {
    case viewPDF
    case freeHandAnnotate
    case textAnnotate
    case addGrade
}

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    let appFontSize: CGFloat = 30
    
    var ezGraderMode: EZGraderMode?
    var pdfView: PDFView!
    var path: UIBezierPath!
    var currentAnnotation: PDFAnnotation!
    var numberOfPagesPerDoc: Int!
    var combinedPDFDocument: PDFDocument!
    var isPerPageMode: Bool!
    var isDot: Bool!
    var appDefaultButtonTintColor: UIColor!
    
    //MARK: Properties
    @IBOutlet var freeHandAnnotateButton: UIBarButtonItem!
    @IBOutlet var textAnnotateButton: UIBarButtonItem!
    @IBOutlet var addGradeButton: UIBarButtonItem!
    @IBOutlet var saveButton: UIBarButtonItem!
    @IBOutlet var doneButton: UIBarButtonItem!
    @IBOutlet var viewPerPageButton: UIBarButtonItem!
    @IBOutlet var viewPerStudentButton: UIBarButtonItem!

    //MARK: Actions
    @IBAction func freeHandAnnotate(_ sender: UIBarButtonItem) {
        self.path = UIBezierPath()

        self.pdfView.isUserInteractionEnabled = false
        
        self.ezGraderMode = EZGraderMode.freeHandAnnotate
        
        self.updateNavigationBar()
    }
    
    @IBAction func textAnnotate(_ sender: UIBarButtonItem) {
        self.pdfView.isUserInteractionEnabled = false
        
        self.ezGraderMode = EZGraderMode.textAnnotate
        
        self.updateNavigationBar()
    }
    
    @IBAction func addGrade(_ sender: UIBarButtonItem) {
        self.pdfView.isUserInteractionEnabled = false
        
        self.ezGraderMode = EZGraderMode.addGrade
        
        self.updateNavigationBar()
    }
    
    @IBAction func save(_ sender: UIBarButtonItem) {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        var docToWriteOut: PDFDocument = PDFDocument()
        
        if self.isPerPageMode {
            let numberOfDocuments: Int = self.combinedPDFDocument.pageCount / self.numberOfPagesPerDoc
            
            for documentNumber: Int in 0...numberOfDocuments - 1 {
                for pageNumber: Int in 0...self.numberOfPagesPerDoc - 1 {
                    docToWriteOut.insert(self.combinedPDFDocument.page(at: (pageNumber * numberOfDocuments + documentNumber))!, at: docToWriteOut.pageCount)
                }
                
                docToWriteOut.write(toFile: "\(documentsPath)/output\(documentNumber + 1).pdf")
                docToWriteOut = PDFDocument()
            }
        } else {
            for pageIndex: Int in 1...self.combinedPDFDocument.pageCount {
                docToWriteOut.insert(self.combinedPDFDocument.page(at: pageIndex - 1)!, at: docToWriteOut.pageCount)
                
                if pageIndex % self.numberOfPagesPerDoc == 0 {
                    docToWriteOut.write(toFile: "\(documentsPath)/output\(pageIndex / self.numberOfPagesPerDoc).pdf")
                    docToWriteOut = PDFDocument()
                }
            }
        }
    }
    
    @IBAction func doneEditing(_ sender: UIBarButtonItem) {
        if self.ezGraderMode == EZGraderMode.freeHandAnnotate {
            self.currentAnnotation = nil
        }
        
        self.pdfView.isUserInteractionEnabled = true
        
        self.ezGraderMode = EZGraderMode.viewPDF
        
        self.updateNavigationBar()
    }
    
    @IBAction func viewPerPage(_ sender: UIBarButtonItem) {
        if self.isPerPageMode == true {
            return
        }
        
        self.isPerPageMode = true
        
        self.viewPerPageButton.tintColor = UIColor.red
        self.viewPerStudentButton.tintColor = self.appDefaultButtonTintColor
        
        let currentPDFPage: PDFPage = self.pdfView.currentPage!
        
        let perPageCombinedPDFDocument = PDFDocument()
        
        let numberOfDocuments: Int = self.combinedPDFDocument.pageCount / self.numberOfPagesPerDoc
        
        for pageIndex: Int in 0...self.numberOfPagesPerDoc - 1 {
            for documentNumber: Int in 0...numberOfDocuments - 1 {
                perPageCombinedPDFDocument.insert(self.combinedPDFDocument.page(at: documentNumber * self.numberOfPagesPerDoc + pageIndex)!, at: perPageCombinedPDFDocument.pageCount)
            }
        }
        
        self.combinedPDFDocument = perPageCombinedPDFDocument
        
        self.pdfView.document = self.combinedPDFDocument
        
        self.pdfView.go(to: currentPDFPage)
        
        for pageIndex: Int in 0...self.combinedPDFDocument.pageCount {
            if self.combinedPDFDocument.page(at: pageIndex)?.annotations != nil {
                for annotation: PDFAnnotation in (self.combinedPDFDocument.page(at: pageIndex)?.annotations)! {
                    print("Anno: " + annotation.contents!)
                    print(annotation.annotationKeyValues[PDFAnnotationKey.widgetCaption])
                }
            }
        }
    }
    
    @IBAction func viewPerStudent(_ sender: UIBarButtonItem) {
        if self.isPerPageMode == false {
            return
        }
        
        self.isPerPageMode = false
        
        self.viewPerPageButton.tintColor = self.appDefaultButtonTintColor
        self.viewPerStudentButton.tintColor = UIColor.red
        
        let currentPDFPage: PDFPage = self.pdfView.currentPage!
        
        let perStudentCombinedPDFDocument = PDFDocument()
        
        let numberOfDocuments: Int = self.combinedPDFDocument.pageCount / self.numberOfPagesPerDoc
        
        for documentNumber: Int in 0...numberOfDocuments - 1 {
            for pageIndex: Int in 0...self.numberOfPagesPerDoc - 1 {
                perStudentCombinedPDFDocument.insert(self.combinedPDFDocument.page(at: pageIndex * numberOfDocuments + documentNumber)!, at: perStudentCombinedPDFDocument.pageCount)
            }
        }
        
        self.combinedPDFDocument = perStudentCombinedPDFDocument
        
        self.pdfView.document = self.combinedPDFDocument
        
        self.pdfView.go(to: currentPDFPage)
    }
    
    @IBAction func startGrading(_ sender: UIButton) {
        let pdfDocumentUrls: [URL] = Bundle.main.urls(forResourcesWithExtension: "pdf", subdirectory: nil)!
        
        var pdfDocument: PDFDocument!
        
        for pdfDocumentUrl: URL in pdfDocumentUrls {
            pdfDocument = PDFDocument(url: pdfDocumentUrl)
            
            if self.numberOfPagesPerDoc == nil {
                self.numberOfPagesPerDoc = pdfDocument.pageCount
            } else if self.numberOfPagesPerDoc != pdfDocument.pageCount {
                // create the alert
                let alert = UIAlertController(title: "Page Count Mismatch", message: "All of the documents to be graded must have the same number of pages.", preferredStyle: UIAlertControllerStyle.alert)
                
                // add the actions (buttons)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                
                // show the alert
                self.present(alert, animated: true, completion: nil)
                
                return
            }
        }
        
        sender.isHidden = true
        
        self.isPerPageMode = true
        self.combinedPDFDocument = PDFDocument()
        
        for pageIndex: Int in 0...self.numberOfPagesPerDoc - 1 {
            for pdfDocumentUrl: URL in pdfDocumentUrls {
                let pdfPage: PDFPage = (PDFDocument(url: pdfDocumentUrl)!.page(at: pageIndex))!
                
                self.combinedPDFDocument.insert(pdfPage, at: self.combinedPDFDocument.pageCount)
            }
        }
        
        self.pdfView = PDFView(frame: UIScreen.main.bounds)
        
        self.pdfView.displayMode = .singlePageContinuous
        self.pdfView.autoScales = true
        self.pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.pdfView.document = self.combinedPDFDocument
        
        self.view.addSubview(self.pdfView)
        
        self.ezGraderMode = EZGraderMode.viewPDF
        
        self.viewPerPageButton.tintColor = UIColor.red
        
        self.navigationController?.isNavigationBarHidden = false
        
        self.updateNavigationBar()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.isNavigationBarHidden = true
        self.appDefaultButtonTintColor = self.viewPerPageButton.tintColor
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.ezGraderMode != EZGraderMode.viewPDF {
            if let touch = touches.first {
                let touchViewCoordinate: CGPoint = touch.location(in: self.pdfView)
                let pdfPageAtTouchedPosition: PDFPage = self.pdfView.page(for: touchViewCoordinate, nearest: true)!
                let pdfPageIndexAtTouchedPosition: Int = (self.pdfView.document?.index(for: pdfPageAtTouchedPosition))!
                let touchPageCoordinate: CGPoint = self.pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
                
                if self.ezGraderMode == EZGraderMode.freeHandAnnotate {
                    self.path.move(to: touchPageCoordinate)
                    
                    self.isDot = true
                } else if self.ezGraderMode == EZGraderMode.textAnnotate {
                    self.showAddTextAnnotationInputDialog(touchPageCoordinate: touchPageCoordinate, pdfPageIndexAtTouchedPosition: pdfPageIndexAtTouchedPosition)
                } else if self.ezGraderMode == EZGraderMode.addGrade {
                    self.showAddGradeInputDialog(touchPageCoordinate: touchPageCoordinate, pdfPageIndexAtTouchedPosition: pdfPageIndexAtTouchedPosition)
                }
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.ezGraderMode == EZGraderMode.freeHandAnnotate {
            if let touch = touches.first {
                let touchViewCoordinate: CGPoint = touch.location(in: self.pdfView)
                let pdfPageAtTouchedPosition: PDFPage = self.pdfView.page(for: touchViewCoordinate, nearest: true)!
                let pdfPageIndexAtTouchedPosition: Int = (self.pdfView.document?.index(for: pdfPageAtTouchedPosition))!
                let touchPageCoordinate: CGPoint = self.pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
                
                self.path.addLine(to: touchPageCoordinate)
                
                self.isDot = false
                
                if self.currentAnnotation != nil {
                    self.pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.removeAnnotation(self.currentAnnotation)
                }
                
                let currentAnnotationPDFBorder: PDFBorder = PDFBorder()
                
                currentAnnotationPDFBorder.lineWidth = 2.0
                
                self.currentAnnotation = PDFAnnotation(bounds: pdfPageAtTouchedPosition.bounds(for: PDFDisplayBox.cropBox), forType: PDFAnnotationSubtype.ink, withProperties: nil)
                self.currentAnnotation.color = .red
                self.currentAnnotation.add(self.path)
                self.currentAnnotation.border = currentAnnotationPDFBorder
                
                self.pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.addAnnotation(self.currentAnnotation)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.ezGraderMode == EZGraderMode.freeHandAnnotate && self.isDot {
            if let touch = touches.first {
                let touchViewCoordinate: CGPoint = touch.location(in: self.pdfView)
                let pdfPageAtTouchedPosition: PDFPage = self.pdfView.page(for: touchViewCoordinate, nearest: true)!
                let pdfPageIndexAtTouchedPosition: Int = (self.pdfView.document?.index(for: pdfPageAtTouchedPosition))!
                let touchPageCoordinate: CGPoint = self.pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
                
                self.path.addLine(to: CGPoint(x: touchPageCoordinate.x + 1, y: touchPageCoordinate.y))
                self.path.addLine(to: CGPoint(x: touchPageCoordinate.x + 1, y: touchPageCoordinate.y + 1))
                self.path.addLine(to: CGPoint(x: touchPageCoordinate.x, y: touchPageCoordinate.y + 1))
                self.path.addLine(to: touchPageCoordinate)
                
                if self.currentAnnotation != nil {
                    self.pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.removeAnnotation(self.currentAnnotation)
                }
                
                let currentAnnotationPDFBorder: PDFBorder = PDFBorder()
                
                currentAnnotationPDFBorder.lineWidth = 2.0
                
                self.currentAnnotation = PDFAnnotation(bounds: pdfPageAtTouchedPosition.bounds(for: PDFDisplayBox.cropBox), forType: PDFAnnotationSubtype.ink, withProperties: nil)
                self.currentAnnotation.color = .red
                self.currentAnnotation.add(self.path)
                self.currentAnnotation.border = currentAnnotationPDFBorder
                
                self.pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.addAnnotation(self.currentAnnotation)
            }
        }
    }
    
    private func showAddTextAnnotationInputDialog(touchPageCoordinate: CGPoint, pdfPageIndexAtTouchedPosition: Int) -> Void {
        let alertController = UIAlertController(title: "New Text Annotation", message: "", preferredStyle: .alert)
        
        let addTextAnnotationAction: UIAlertAction = UIAlertAction(title: "Add Text Annotation", style: .default) { (alert: UIAlertAction!) in
            let enteredText: String = (alertController.textFields?[0].text)!
            let enteredTextSize: CGSize = self.getTextSize(text: enteredText + "  ")
            
            let textAnnotationFreeTextAnnotation: PDFAnnotation = PDFAnnotation(bounds: CGRect(origin: touchPageCoordinate, size: CGSize(width: enteredTextSize.height, height: enteredTextSize.width)), forType: .freeText, withProperties: nil)
            
            textAnnotationFreeTextAnnotation.fontColor = UIColor.red
            textAnnotationFreeTextAnnotation.font = UIFont.systemFont(ofSize: self.appFontSize)
            textAnnotationFreeTextAnnotation.color = UIColor.clear
            textAnnotationFreeTextAnnotation.isReadOnly = true
            textAnnotationFreeTextAnnotation.contents = enteredText
            textAnnotationFreeTextAnnotation.setValue("Text Annotation", forAnnotationKey: PDFAnnotationKey.widgetCaption)
            
            self.pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.addAnnotation(textAnnotationFreeTextAnnotation)
        }
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { (alert: UIAlertAction!) in }
        
        alertController.addTextField { (textField) in
            textField.placeholder = "Text Annotation"
        }
        
        alertController.addAction(addTextAnnotationAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func showAddGradeInputDialog(touchPageCoordinate: CGPoint, pdfPageIndexAtTouchedPosition: Int) -> Void {
        let alertController = UIAlertController(title: "New Grade", message: "", preferredStyle: .alert)
        
        let addGradeAction: UIAlertAction = UIAlertAction(title: "Add Grade", style: .default) { (alert: UIAlertAction!) in
            self.addGradeToAllStudents(pointsEarned: (alertController.textFields?[0].text)!, maximumPoints: (alertController.textFields?[1].text)!, touchPageCoordinate: touchPageCoordinate, pdfPageIndexAtTouchedPosition: pdfPageIndexAtTouchedPosition)
        }
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { (alert: UIAlertAction!) in }
        
        alertController.addTextField { (textField) in
            textField.placeholder = "Points Earned"
            textField.keyboardType = UIKeyboardType.decimalPad
        }
        
        alertController.addTextField { (textField) in
            textField.placeholder = "Maximum Points"
            textField.keyboardType = UIKeyboardType.decimalPad
        }
        
        alertController.addAction(addGradeAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func addGradeToAllStudents(pointsEarned: String, maximumPoints: String, touchPageCoordinate: CGPoint, pdfPageIndexAtTouchedPosition: Int) -> Void {
        let gradeForCurrentStudent: String = pointsEarned + " / " + maximumPoints
        let gradeForOtherStudents: String =  "? / " + maximumPoints
        
        if self.isPerPageMode {
            let numberOfDocuments: Int = self.combinedPDFDocument.pageCount / self.numberOfPagesPerDoc
            let indexOfPDFPageOfFirstStudent: Int = pdfPageIndexAtTouchedPosition - (pdfPageIndexAtTouchedPosition % numberOfDocuments)
            
            for indexOfPDFPageToAddAnnotationTo: Int in indexOfPDFPageOfFirstStudent...indexOfPDFPageOfFirstStudent + numberOfDocuments - 1 {
                self.pdfView.document?.page(at: indexOfPDFPageToAddAnnotationTo)?.addAnnotation(createGradeFreeTextAnnotation(gradeText: indexOfPDFPageToAddAnnotationTo == pdfPageIndexAtTouchedPosition ? gradeForCurrentStudent : gradeForOtherStudents, touchPageCoordinate: touchPageCoordinate))
            }
        } else {
            for indexOfPDFPageToAddAnnotationTo: Int in stride(from: pdfPageIndexAtTouchedPosition % self.numberOfPagesPerDoc, to: self.combinedPDFDocument.pageCount - 1, by: self.numberOfPagesPerDoc) {
                self.pdfView.document?.page(at: indexOfPDFPageToAddAnnotationTo)?.addAnnotation(createGradeFreeTextAnnotation(gradeText: indexOfPDFPageToAddAnnotationTo == pdfPageIndexAtTouchedPosition ? gradeForCurrentStudent : gradeForOtherStudents, touchPageCoordinate: touchPageCoordinate))
            }
        }
    }
    
    private func createGradeFreeTextAnnotation(gradeText: String, touchPageCoordinate: CGPoint) -> PDFAnnotation {
        let gradeTextSize: CGSize = self.getTextSize(text: gradeText + "  ")
        
        let gradeFreeTextAnnotation: PDFAnnotation = PDFAnnotation(bounds: CGRect(origin: touchPageCoordinate, size: CGSize(width: gradeTextSize.height, height: gradeTextSize.width)), forType: .freeText, withProperties: nil)
        
        gradeFreeTextAnnotation.fontColor = UIColor.red
        gradeFreeTextAnnotation.font = UIFont.systemFont(ofSize: self.appFontSize)
        gradeFreeTextAnnotation.color = UIColor.clear
        gradeFreeTextAnnotation.isReadOnly = true
        gradeFreeTextAnnotation.contents = gradeText
        gradeFreeTextAnnotation.setValue("Grade Annotation", forAnnotationKey: PDFAnnotationKey.widgetCaption)
        
        return gradeFreeTextAnnotation
    }
    
    private func getTextSize(text: String) -> CGSize {
        let font = UIFont.systemFont(ofSize: self.appFontSize)
        let fontAttributes = [NSAttributedStringKey.font: font]
        
        return (text as NSString).size(withAttributes: fontAttributes)
    }
    
    private func updateNavigationBar() -> Void {
        switch self.ezGraderMode {
        case .viewPDF?:
            self.navigationItem.leftBarButtonItems = [self.freeHandAnnotateButton, self.textAnnotateButton, self.addGradeButton, self.saveButton]
            self.navigationItem.rightBarButtonItems = [self.viewPerStudentButton, self.viewPerPageButton]
            self.navigationItem.title = ""
        case .freeHandAnnotate?,
             .textAnnotate?,
             .addGrade?:
            self.navigationItem.leftBarButtonItems = [self.doneButton]
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
