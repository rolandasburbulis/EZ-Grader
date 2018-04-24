//
//  ViewController.swift
//  EZ Grader
//
//  Copyright © 2018 RIT. All rights reserved.
//

import PDFKit
import MobileCoreServices

class SelectPDFDocumentsToGradeViewController: UIViewController, UIDocumentPickerDelegate {
    var selectedPDFDocumentToGradeURLs: [URL] = []
    
    //MARK: Actions
    @IBAction func selectPDFsToGrade(_ selectedPDFsToGradeButton: UIButton) {
        let uiDocumentPickerViewController: UIDocumentPickerViewController = UIDocumentPickerViewController(documentTypes: [String(kUTTypePDF)], in: UIDocumentPickerMode.import)
        
        uiDocumentPickerViewController.delegate = self
        uiDocumentPickerViewController.modalPresentationStyle = .fullScreen
        uiDocumentPickerViewController.allowsMultipleSelection = true
        
        self.present(uiDocumentPickerViewController, animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) -> Void {
        super.viewWillAppear(true)
        
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let gradePDFsViewController: GradePDFDocumentsViewController = segue.destination as? GradePDFDocumentsViewController {
            gradePDFsViewController.pdfDocumentURLs = self.selectedPDFDocumentToGradeURLs
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt selectedPDFDocumentToGradeURLs: [URL]) -> Void {
        self.selectedPDFDocumentToGradeURLs = selectedPDFDocumentToGradeURLs
        
        var pdfDocument: PDFDocument!
         
        var numberOfPagesPerPDFDocument: Int!
         
        for pdfDocumentURL: URL in selectedPDFDocumentToGradeURLs {
            pdfDocument = PDFDocument(url: pdfDocumentURL)
         
            if numberOfPagesPerPDFDocument == nil {
                numberOfPagesPerPDFDocument = pdfDocument.pageCount
            } else if numberOfPagesPerPDFDocument != pdfDocument.pageCount {
                // create the alert
                let pdfDocumentPageCountMismatchUIAlertController: UIAlertController = UIAlertController(title: "PDF Document Page Count Mismatch", message: "All of the PDF documents to be graded must have the same number of pages.", preferredStyle: UIAlertControllerStyle.alert)
         
                // add the actions (buttons)
                pdfDocumentPageCountMismatchUIAlertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
         
                // show the alert
                self.present(pdfDocumentPageCountMismatchUIAlertController, animated: true, completion: nil)
                
                return
            }
        }
        
        performSegue(withIdentifier: "selectedPDFDocumentsToGradeSegue", sender: nil)
    }
}
