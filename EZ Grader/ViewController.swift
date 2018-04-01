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
    var ezGraderMode: EZGraderMode?
    var pdfView: PDFView!
    var path: UIBezierPath!
    var currentAnnotation: PDFAnnotation!
    var numberOfPagesPerDoc: Int!
    var perPageCombined: PDFDocument!
    var perStudentCombined: PDFDocument!
    var isPerPageMode: Bool = true
    
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
            let numberOfDocuments: Int = self.perPageCombined.pageCount / self.numberOfPagesPerDoc
            
            for documentNumber: Int in 0...numberOfDocuments - 1 {
                for pageNumber: Int in 0...self.numberOfPagesPerDoc - 1 {
                    docToWriteOut.insert(self.perPageCombined.page(at: (pageNumber * numberOfDocuments + documentNumber))!.copy() as! PDFPage, at: docToWriteOut.pageCount)
                }
                
                docToWriteOut.write(toFile: "\(documentsPath)/output\(documentNumber + 1).pdf")
                docToWriteOut = PDFDocument()
            }
        } else {
            for pageIndex: Int in 1...self.perStudentCombined.pageCount {
                docToWriteOut.insert(self.perStudentCombined.page(at: pageIndex - 1)!.copy() as! PDFPage, at: docToWriteOut.pageCount)
                
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
        self.pdfView.document = self.perPageCombined
        
        self.isPerPageMode = true
    }
    
    @IBAction func viewPerStudent(_ sender: UIBarButtonItem) {
        self.pdfView.document = self.perStudentCombined
        
        self.isPerPageMode = false
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
        
        self.perStudentCombined = PDFDocument()
        self.perPageCombined = PDFDocument()
        
        for pdfDocumentUrl: URL in pdfDocumentUrls {
            pdfDocument = PDFDocument(url: pdfDocumentUrl)
            
            for pageIndex: Int in 0...pdfDocument.pageCount - 1 {
                self.perStudentCombined.insert(pdfDocument.page(at: pageIndex)!.copy() as! PDFPage, at: self.perStudentCombined.pageCount)
            }
        }
        
        for pageIndex: Int in 0...self.numberOfPagesPerDoc - 1 {
            for pdfDocumentUrl: URL in pdfDocumentUrls {
                let pdfPage: PDFPage = (PDFDocument(url: pdfDocumentUrl)!.page(at: pageIndex))!.copy() as! PDFPage
                
                self.perPageCombined.insert(pdfPage, at: self.perPageCombined.pageCount)
            }
        }
        
        self.pdfView = PDFView(frame: UIScreen.main.bounds)
        
        self.pdfView.displayMode = .singlePageContinuous
        self.pdfView.autoScales = true
        self.pdfView.document = self.perPageCombined
        
        self.view.addSubview(self.pdfView)
        
        self.ezGraderMode = EZGraderMode.viewPDF
        
        self.navigationController?.isNavigationBarHidden = false
        
        self.updateNavigationBar()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.isNavigationBarHidden = true
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
                    
                    /*let pathRect = CGRect(x: touchPageCoordinate.x, y: touchPageCoordinate.y, width: 1, height: 1)
                     let tempPath = UIBezierPath(ovalIn: pathRect)
                     
                     self.currentAnnotation = PDFAnnotation(bounds: pdfPageAtTouchedPosition.bounds(for: PDFDisplayBox.cropBox), forType: .ink, withProperties: nil)
                     self.currentAnnotation.color = .red
                     self.currentAnnotation.add(tempPath)
                     
                     self.pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.addAnnotation(self.currentAnnotation)
                     
                     let rect = CGRect(x: 100.0, y: 100.0, width: 100.0, height: 100.0)
                     
                     let annotation = PDFAnnotation(bounds: rect, forType: .ink, withProperties: nil)
                     annotation.backgroundColor = .blue
                     
                     let pathRect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
                     let path = UIBezierPath(ovalIn: pathRect)
                     annotation.add(path)*/
                } else if self.ezGraderMode == EZGraderMode.addGrade {
                    self.showInputDialog(touchPageCoordinate: touchPageCoordinate, pdfPageIndexAtTouchedPosition: pdfPageIndexAtTouchedPosition)
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
                
                if self.currentAnnotation != nil {
                    self.pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.removeAnnotation(self.currentAnnotation)
                }
                
                self.currentAnnotation = PDFAnnotation(bounds: pdfPageAtTouchedPosition.bounds(for: PDFDisplayBox.cropBox), forType: .ink, withProperties: nil)
                self.currentAnnotation.color = .red
                self.currentAnnotation.add(self.path)
                
                self.pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.addAnnotation(self.currentAnnotation)
            }
        }
    }
    
    private func showInputDialog(touchPageCoordinate: CGPoint, pdfPageIndexAtTouchedPosition: Int) -> Void {
        let alertController = UIAlertController(title: "Enter Grade", message: "", preferredStyle: .alert)
        
        let addGradeAction: UIAlertAction = UIAlertAction(title: "Add Grade", style: .default) { (alert: UIAlertAction!) in
            let gradeFreeTextAnnotation: PDFAnnotation = PDFAnnotation(bounds: CGRect(origin: touchPageCoordinate, size: CGSize(width: 25, height: 70)), forType: .freeText, withProperties: nil)
            
            gradeFreeTextAnnotation.fontColor = UIColor.red
            gradeFreeTextAnnotation.color = UIColor.clear
            gradeFreeTextAnnotation.isReadOnly = true
            gradeFreeTextAnnotation.contents = (alertController.textFields?[0].text)! + "/" + (alertController.textFields?[1].text)!
            
            self.pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.addAnnotation(gradeFreeTextAnnotation)
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
    
    private func updateNavigationBar() -> Void {
        switch self.ezGraderMode {
        case .viewPDF?:
            self.navigationItem.leftBarButtonItems = [self.freeHandAnnotateButton, self.textAnnotateButton, self.addGradeButton, self.saveButton]
            self.navigationItem.rightBarButtonItems = [self.viewPerPageButton, self.viewPerStudentButton]
            self.navigationItem.title = ""
        case .freeHandAnnotate?,
             .textAnnotate?,
             .addGrade?:
            let currentDoneButtonTintColor: UIColor! = self.doneButton.tintColor
            self.doneButton.tintColor = .clear
            self.doneButton.tintColor = currentDoneButtonTintColor
            
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

