//
//  ViewController.swift
//  EZ Grader
//
//  Copyright © 2018 RIT. All rights reserved.
//

import PDFKit

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    var pdfView: PDFView!
    var path: UIBezierPath!
    var currentAnnotation: PDFAnnotation!
    var numberOfPagesPerDoc: Int!
    var perPageCombined: PDFDocument!
    var perStudentCombined: PDFDocument!
    var isPerPageMode: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        
        /*let documentProvider = UIDocumentPickerViewController(documentTypes: ["public.image", "public.audio", "public.movie", "public.text", "public.item", "public.content", "public.source-code"], in: .import)
        documentProvider.delegate = self as? UIDocumentPickerDelegate
        
        self.present(documentProvider, animated: true, completion: nil)*/
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func openPDFAction(_ sender: Any) {
        let pdfDocumentUrls: [URL] = Bundle.main.urls(forResourcesWithExtension: "pdf", subdirectory: nil)!
        
        var pdfDocument: PDFDocument!
        
        for pdfDocumentUrl: URL in pdfDocumentUrls {
            pdfDocument = PDFDocument(url: pdfDocumentUrl)
            
            if numberOfPagesPerDoc == nil {
                numberOfPagesPerDoc = pdfDocument.pageCount
            } else if numberOfPagesPerDoc != pdfDocument.pageCount {
                // create the alert
                let alert = UIAlertController(title: "Page Count Mismatch", message: "All of the documents to be graded must have the same number of pages.", preferredStyle: UIAlertControllerStyle.alert)
                
                // add the actions (buttons)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                
                // show the alert
                self.present(alert, animated: true, completion: nil)
                
                return
            }
        }
        
        (sender as? UIButton)?.isHidden = true
        
        perStudentCombined = PDFDocument()
        perPageCombined = PDFDocument()
        
        for pdfDocumentUrl: URL in pdfDocumentUrls {
            pdfDocument = PDFDocument(url: pdfDocumentUrl)
            
            for pageIndex: Int in 0...pdfDocument.pageCount - 1 {
                perStudentCombined.insert(pdfDocument.page(at: pageIndex)!.copy() as! PDFPage, at: perStudentCombined.pageCount)
            }
        }
        
        for pageIndex: Int in 0...numberOfPagesPerDoc - 1 {
            for pdfDocumentUrl: URL in pdfDocumentUrls {
                let pdfPage: PDFPage = (PDFDocument(url: pdfDocumentUrl)!.page(at: pageIndex))!.copy() as! PDFPage
                
                perPageCombined.insert(pdfPage, at: perPageCombined.pageCount)
            }
        }
        
        pdfView = PDFView(frame: UIScreen.main.bounds)
        
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        pdfView.document = perPageCombined
        
        view.addSubview(pdfView)
        
        let annotationsBtn = UIBarButtonItem(title: "Annotate", style: .plain, target: self, action: #selector(annotations))
        let perPageBtn = UIBarButtonItem(title: "Per Page", style: .plain, target: self, action: #selector(viewPerPage))
        let perStudentBtn = UIBarButtonItem(title: "Per Student", style: .plain, target: self, action: #selector(viewPerStudent))
        let saveBtn = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(save))
        
        navigationItem.leftBarButtonItems = [annotationsBtn, perPageBtn, perStudentBtn, saveBtn]
    }
    
    @objc func annotations() {
        if(pdfView.isUserInteractionEnabled) {
            path = UIBezierPath()
            path.lineWidth = 7
        } else {
            currentAnnotation = nil
        }

        pdfView.isUserInteractionEnabled = !pdfView.isUserInteractionEnabled
    }
    
    @objc func viewPerPage() {
        pdfView.document = perPageCombined
        
        isPerPageMode = true
    }
    
    @objc func viewPerStudent() {
        pdfView.document = perStudentCombined
        
        isPerPageMode = false
    }
    
    @objc func save() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        var docToWriteOut: PDFDocument = PDFDocument()
    
        if isPerPageMode {
            let numberOfDocuments: Int = perPageCombined.pageCount / numberOfPagesPerDoc
            
            for documentNumber: Int in 0...numberOfDocuments - 1 {
                for pageNumber: Int in 0...numberOfPagesPerDoc - 1 {
                    docToWriteOut.insert(perPageCombined.page(at: (pageNumber * numberOfDocuments + documentNumber))!.copy() as! PDFPage, at: docToWriteOut.pageCount)
                }
                
                docToWriteOut.write(toFile: "\(documentsPath)/output\(documentNumber + 1).pdf")
                docToWriteOut = PDFDocument()
            }
        } else {
            for pageIndex: Int in 1...perStudentCombined.pageCount {
                docToWriteOut.insert(perStudentCombined.page(at: pageIndex - 1)!.copy() as! PDFPage, at: docToWriteOut.pageCount)
                
                if pageIndex % numberOfPagesPerDoc == 0 {
                    docToWriteOut.write(toFile: "\(documentsPath)/output\(pageIndex / numberOfPagesPerDoc).pdf")
                    docToWriteOut = PDFDocument()
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let touchViewCoordinate: CGPoint = touch.location(in: pdfView)
            let pdfPageAtTouchedPosition: PDFPage = pdfView.page(for: touchViewCoordinate, nearest: true)!
            let touchPageCoordinate: CGPoint = pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
            
            path.move(to: touchPageCoordinate)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let touchViewCoordinate: CGPoint = touch.location(in: pdfView)
            let pdfPageAtTouchedPosition: PDFPage = pdfView.page(for: touchViewCoordinate, nearest: true)!
            let pdfPageIndexAtTouchedPosition: Int = (pdfView.document?.index(for: pdfPageAtTouchedPosition))!
            let touchPageCoordinate: CGPoint = pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
            
            path.addLine(to: touchPageCoordinate)
            
            if( currentAnnotation != nil ) {
                pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.removeAnnotation(currentAnnotation)
            }
                
            currentAnnotation = PDFAnnotation(bounds: pdfPageAtTouchedPosition.bounds(for: PDFDisplayBox.cropBox), forType: .ink, withProperties: nil)
            currentAnnotation.color = .red
            currentAnnotation.add(path)
            
            pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.addAnnotation(currentAnnotation)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let touchViewCoordinate: CGPoint = touch.location(in: pdfView)
            let pdfPageAtTouchedPosition: PDFPage = pdfView.page(for: touchViewCoordinate, nearest: true)!
            let pdfPageIndexAtTouchedPosition: Int = (pdfView.document?.index(for: pdfPageAtTouchedPosition))!
            let touchPageCoordinate: CGPoint = pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
            
            let numeratorBox = CGRect(origin: CGPoint(x: touchPageCoordinate.x, y: touchPageCoordinate.y + 20), size: CGSize(width: 30, height: 50))
            let fractionSymbolBox = CGRect(origin: touchPageCoordinate, size: CGSize(width: 30, height: 20))
            let denominatorBox = CGRect(origin: CGPoint(x: touchPageCoordinate.x, y: touchPageCoordinate.y - 50), size: CGSize(width: 30, height: 50))

            let numeratorFreeTextField: PDFAnnotation = PDFAnnotation(bounds: numeratorBox, forType: .freeText, withProperties: nil)
            
            var font: UIFont = UIFont(descriptor: UIFontDescriptor(), size: 25)
            
            numeratorFreeTextField.color = UIColor.yellow
            numeratorFreeTextField.font = font
            numeratorFreeTextField.isReadOnly = false
            numeratorFreeTextField.contents = "2"
            
            let fractionSymbolFreeTextField: PDFAnnotation = PDFAnnotation(bounds: fractionSymbolBox, forType: .freeText, withProperties: nil)
            
            fractionSymbolFreeTextField.color = UIColor.lightGray
            //fractionSymbolFreeTextField.font = UIFont(descriptor: UIFontDescriptor(), size: 25)
            fractionSymbolFreeTextField.isReadOnly = true
            fractionSymbolFreeTextField.contents = "/"
            
            let denominatorSymbolFreeTextAnnotation: PDFAnnotation = PDFAnnotation(bounds: denominatorBox, forType: .freeText, withProperties: nil)
            
            denominatorSymbolFreeTextAnnotation.color = UIColor.yellow
            //denominatorSymbolFreeTextAnnotation.font = UIFont(descriptor: UIFontDescriptor(), size: 25)
            denominatorSymbolFreeTextAnnotation.isReadOnly = false
            denominatorSymbolFreeTextAnnotation.contents = "4"
            
            pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.addAnnotation(numeratorFreeTextField);
            pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.addAnnotation(fractionSymbolFreeTextField);
            pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.addAnnotation(denominatorSymbolFreeTextAnnotation);
        }
    }
}
