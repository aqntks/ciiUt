//
//  PostProcessor.swift
//  ObjectDetection
//
//  Created by Sukhong Cho on 2022/02/15.
//  Copyright © 2022 Y Media Labs. All rights reserved.
//

import Foundation

struct Card {
    var cardType: Int = 0
    var cardNumber: String = ""
    var cardMonth: String = ""
    var cardYear: String = ""
    var errcode: Int = 10
}

class PostProcessor {
    
    func card(result: Result) -> Card {
        let predictions = result.inferences
        var index: Int = 0
        var score: Float = 0
        var resultText: String = ""
        var number: Inference!
        var date: Inference!
        var date_list: [Inference] = []
        var numberValue: String = ""
        var dateValue: String = ""
        var cardType: Int = 0
        var cardNumber: String = ""
        var cardMonth: String = ""
        var cardYear: String = ""
        
        var cardResult = Card()
        
        let sortXPrediction = predictions.sorted{$0.rect.origin.x < $1.rect.origin.x}
        
        for cls in sortXPrediction {
            if cls.className == "Number" {
                number = cls
            }
            else if cls.className == "Date" {
                date = cls
                date_list.append(cls)
            }
            else {continue}
        }
        
      
        // 검출 실패 시 코드 작성
        if number == nil {
            print("영역 검출 실패")
            return cardResult
        }
        
        // 두줄 카드 번호 처리를 위한 Y정렬 후 X정렬
        var numberTemp = [Inference]()
        
        for cls in sortXPrediction {
            if cls.rect.minY > number.rect.minY && cls.rect.maxY < number.rect.maxY && cls.rect.minX > number.rect.minX && cls.rect.maxX < number.rect.maxX {
                numberValue.append(cls.className)
                numberTemp.append(cls)
                
                score = score + cls.confidence
                index = index + 1
            }
            else if date != nil && cls.rect.minY > date.rect.minY && cls.rect.maxY < date.rect.maxY && cls.rect.minX > date.rect.minX && cls.rect.maxX < date.rect.maxX {
                dateValue.append(cls.className)
                score = score + cls.confidence
                index = index + 1
            }
            else {continue}
        }
        
        if numberValue.count != 15 && date_list.count >= 2 {
            date = date_list[0]
            for d in date_list {
                if d.confidence > date.confidence {
                    date = d
                }
            }
            dateValue = ""
            for cls in sortXPrediction {
                if date != nil && cls.rect.minY > date.rect.minY && cls.rect.maxY < date.rect.maxY && cls.rect.minX > date.rect.minX && cls.rect.maxX < date.rect.maxX {
                    dateValue.append(cls.className)
                    score = score + cls.confidence
                    index = index + 1
                }
                else {continue}
            }
        }
        
        // Type - 1 일반 카드 - 카드번호 16 자리
        if numberValue.count == 16 && dateValue.count == 5 {
            cardType = 1
            
           
            if number.rect.width >= number.rect.height {
                // 두줄 카드 번호 처리를 위한 Y정렬 후 X정렬
                var numberLine1 = [Inference]()
                var numberLine2 = [Inference]()
                var numberIndex: Int = 0
                
                
                let sortYNumber = numberTemp.sorted{$0.rect.origin.y < $1.rect.origin.y}
                for cls in sortYNumber {
                    if numberIndex < 8 {
                        numberLine1.append(cls)
                        numberIndex = numberIndex + 1
                    }
                    else{
                        numberLine2.append(cls)
                    }
                }
                numberLine1.sort{$0.rect.origin.x < $1.rect.origin.x}
                numberLine2.sort{$0.rect.origin.x < $1.rect.origin.x}
                var twoLineNumber: String = ""
                for n in numberLine1{
                    twoLineNumber.append(n.className)
                }
                for n in numberLine2{
                    twoLineNumber.append(n.className)
                }
                
                // 검출 실패 시 코드 작성
                if twoLineNumber.count != 16 {
                    print("박스 내 갯수 부족2")
                    return cardResult
                }
                // 결과 저장
                if (numberLine1[0].rect.maxY < numberLine2[0].rect.minY) && (numberLine1[3].rect.maxY < numberLine2[3].rect.minY) && (numberLine1[5].rect.maxY < numberLine2[5].rect.minY) {
                    cardNumber = twoLineNumber
                }
                else {
                    cardNumber = numberValue
                }
                
            }
            else {
                // 4줄짜리 정렬
                var numberLine1 = [Inference]()
                var numberLine2 = [Inference]()
                var numberLine3 = [Inference]()
                var numberLine4 = [Inference]()
                var numberIndex: Int = 0
                
                let sortYNumber = numberTemp.sorted{$0.rect.origin.y < $1.rect.origin.y}
                for cls in sortYNumber {
                    if numberIndex < 4 {
                        numberLine1.append(cls)
                        numberIndex = numberIndex + 1
                    }
                    else if numberIndex < 8 {
                        numberLine2.append(cls)
                        numberIndex = numberIndex + 1
                    }
                    else if numberIndex < 12 {
                        numberLine3.append(cls)
                        numberIndex = numberIndex + 1
                    }
                    else {
                        numberLine4.append(cls)
                        numberIndex = numberIndex + 1
                    }
                }
                numberLine1.sort{$0.rect.origin.x < $1.rect.origin.x}
                numberLine2.sort{$0.rect.origin.x < $1.rect.origin.x}
                numberLine3.sort{$0.rect.origin.x < $1.rect.origin.x}
                numberLine4.sort{$0.rect.origin.x < $1.rect.origin.x}
                var fourLineNumber: String = ""
                for n in numberLine1{
                    fourLineNumber.append(n.className)
                }
                for n in numberLine2{
                    fourLineNumber.append(n.className)
                }
                for n in numberLine3{
                    fourLineNumber.append(n.className)
                }
                for n in numberLine4{
                    fourLineNumber.append(n.className)
                }
                
                cardNumber = fourLineNumber
            }
            
            
            cardMonth = String(dateValue[...dateValue.index(dateValue.startIndex, offsetBy: 1)]).replacingOccurrences(of: "/", with: "")
            cardYear = String(dateValue[dateValue.index(dateValue.startIndex, offsetBy: 3)...]).replacingOccurrences(of: "/", with: "")
            
            if !(luhnCheck(cardNumber as String)) {
                print("카드번호 체크섬")
                cardResult.errcode = 99
                return cardResult
            }
            if Int(cardMonth)! > 12 || Int(cardMonth)! < 1 {
                print("month 값 오류")
                return cardResult
            }
            if Int(cardYear)! > 32 {
                print("year 값 오류")
                return cardResult
            }

//            var countNumber: Int = 1
//            var numberResult: String = ""
//            for s in numberValue{
//                numberResult.append(s)
//                if countNumber % 4 == 0 {numberResult.append(" ")}
//                countNumber = countNumber + 1
//            }
//            resultText.append(numberResult)
//            resultText.append("\n")
//            resultText.append(dateValue)
            
        }
        // Type - 2 아메리칸 익스프레스
        else if numberValue.count == 15 && (dateValue.count == 5 || dateValue.count == 0) {
            cardType = 2
            
            let sortXNumber = numberTemp.sorted{$0.rect.origin.x < $1.rect.origin.x}
            
            var cardNumbers: String = ""
            for n in sortXNumber {
                cardNumbers.append(n.className)
            }
            cardNumber = cardNumbers
            
            if date != nil && dateValue.count == 5 {
                cardMonth = String(dateValue[...dateValue.index(dateValue.startIndex, offsetBy: 1)]).replacingOccurrences(of: "/", with: "")
                cardYear = String(dateValue[dateValue.index(dateValue.startIndex, offsetBy: 3)...]).replacingOccurrences(of: "/", with: "")
                
                if Int(cardMonth)! > 12 || Int(cardMonth)! < 1 {
                    print("month 값 오류")
                    return cardResult
                }
                if Int(cardYear)! > 32 {
                    print("year 값 오류")
                    return cardResult
                }
            }
            
            if !(luhnCheck(cardNumber as String)) {
                print("카드번호 체크섬")
                    cardResult.errcode = 99
                return cardResult
            }
            
        }
        // Type - 3 다이너스 카드
        else if numberValue.count == 14 && dateValue.count == 5 {
            cardType = 3
            
            let sortXNumber = numberTemp.sorted{$0.rect.origin.x < $1.rect.origin.x}
            
            var cardNumbers: String = ""
            for n in sortXNumber {
                cardNumbers.append(n.className)
            }
            cardNumber = cardNumbers
            
            if date != nil {
                cardMonth = String(dateValue[...dateValue.index(dateValue.startIndex, offsetBy: 1)]).replacingOccurrences(of: "/", with: "")
                cardYear = String(dateValue[dateValue.index(dateValue.startIndex, offsetBy: 3)...]).replacingOccurrences(of: "/", with: "")
                
                if Int(cardMonth)! > 12 || Int(cardMonth)! < 1 {
                    print("month 값 오류")
                    return cardResult
                }
                if Int(cardYear)! > 32 {
                    print("year 값 오류")
                    return cardResult
                }
            }
            
            if !(luhnCheck(cardNumber as String)) {
                print("카드번호 체크섬")
            cardResult.errcode = 99
                return cardResult
            }
        
        }
        else {
            print("박스 내 갯수 부족1")
            cardType = 0
            return cardResult
        }

        cardResult.cardType = cardType
        cardResult.cardNumber = cardNumber
        cardResult.cardMonth = cardMonth
        cardResult.cardYear = cardYear
    
        return cardResult
    }
    
    func luhnCheck(_ number: String) -> Bool {
        var sum = 0
        let digitStrings = number.reversed().map { String($0) }

        for tuple in digitStrings.enumerated() {
            if let digit = Int(tuple.element) {
                let odd = tuple.offset % 2 == 1

                switch (odd, digit) {
                case (true, 9):
                    sum += 9
                case (true, 0...8):
                    sum += (digit * 2) % 9
                default:
                    sum += digit
                }
            } else {
                return false
            }
        }
        return sum % 10 == 0
    }
}
