
import Foundation
import UIKit

class ResultController: UIViewController, UINavigationControllerDelegate, UITextFieldDelegate {

    
    @IBOutlet var cardNumberField: UITextField!
    @IBOutlet weak var expireLabel: UILabel!
    @IBOutlet weak var expireTextField: UITextField!
    
    var card: Card!
    var cardMonth: String!
    var cardYear: String!
    var cardResult: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        self.navigationController?.isNavigationBarHidden = false
//        self.navigationController?.navigationBar.backItem?.backBarButtonItem?.accessibilityElementsHidden = true
        setResult()
    }
    
    // UI 필드에 결과 값 적용
    func setResult() {
        let cardNumber = card.cardNumber
        
        if card.cardType == 1 {
            var numberField = String(cardNumber[...cardNumber.index(cardNumber.startIndex, offsetBy: 3)])
            numberField += " "
            numberField += String(cardNumber[cardNumber.index(cardNumber.startIndex, offsetBy: 4)...cardNumber.index(cardNumber.startIndex, offsetBy: 7)])
            numberField += " "
            numberField += String(cardNumber[cardNumber.index(cardNumber.startIndex, offsetBy: 8)...cardNumber.index(cardNumber.startIndex, offsetBy: 11)])
            numberField += " "
            numberField += String(cardNumber[cardNumber.index(cardNumber.startIndex, offsetBy: 12)...])
            cardNumberField.text = numberField
        }
        else if card.cardType == 2 {
            var numberField = String(cardNumber[...cardNumber.index(cardNumber.startIndex, offsetBy: 3)])
            numberField += " "
            numberField += String(cardNumber[cardNumber.index(cardNumber.startIndex, offsetBy: 4)...cardNumber.index(cardNumber.startIndex, offsetBy: 9)])
            numberField += " "
            numberField += String(cardNumber[cardNumber.index(cardNumber.startIndex, offsetBy: 10)...])
            cardNumberField.text = numberField
        }
        else if card.cardType == 3 {
            var numberField = String(cardNumber[...cardNumber.index(cardNumber.startIndex, offsetBy: 3)])
            numberField += " "
            numberField += String(cardNumber[cardNumber.index(cardNumber.startIndex, offsetBy: 4)...cardNumber.index(cardNumber.startIndex, offsetBy: 9)])
            numberField += " "
            numberField += String(cardNumber[cardNumber.index(cardNumber.startIndex, offsetBy: 10)...])
            cardNumberField.text = numberField
        }
        
        if card.cardYear.count == 1 {
            card.cardYear = "0" + card.cardYear
        }
        if card.cardMonth.count != 0 && card.cardYear.count != 0 {
            expireTextField.text = card.cardMonth + "/" + card.cardYear
        }
        else {
            expireTextField.text = ""
        }
    }

    @IBAction func back(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?){
         self.view.endEditing(true)

   }
}

