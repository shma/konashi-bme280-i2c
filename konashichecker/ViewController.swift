//
//  ViewController.swift
//  konashichecker
//
//  Created by Matsuno Shunya on 2019/04/10.
//  Copyright © 2019年 Matsuno Shunya. All rights reserved.
//

import UIKit
import konashi_ios_sdk

class ViewController: UIViewController {
    // BME 280　Settings
    let OSRST = 1           //Temperature oversampling x 1
    let OSRSP = 1           //Pressure oversampling x 1
    let OSRSH = 1           //Humidity oversampling x 1
    let NORMAL_MODE = 3           //Normal mode
    let TSB = 5         //Tstandby 1000ms
    let FILTER = 0           //Filter off
    let SPI3WEN = 0         //3-wire SPI Disable
    let ADDR_ID = 0xD0
    let ADDR_BME280: UInt8 = 0x76
    
    var readSequenceCount = 0
    var datas = [UInt8]()
    
    var digT1: UInt16 = 0
    var digT2: Int16 = 0
    var digT3: Int16 = 0
    var digP1: UInt16 = 0
    var digP2: Int16 = 0
    var digP3: Int16 = 0
    var digP4: Int16 = 0
    var digP5: Int16 = 0
    var digP6: Int16 = 0
    var digP7: Int16 = 0
    var digP8: Int16 = 0
    var digP9: Int16 = 0
    var digH1: Int8 = 0
    var digH2: Int16 = 0
    var digH3: Int8 = 0
    var digH4: Int16 = 0
    var digH5: Int16 = 0
    var digH6: Int8 = 0
    
    // BME280のかキャリブレーション用グローバル変数。重要
    var tFine: Int = 0
    
    override func viewDidLoad() {
        let CTRL_MEAS_REG = (OSRST << 5) | (OSRSP << 2) | NORMAL_MODE;
        let CONFIG_REG    = (TSB << 5) | (FILTER << 2) | SPI3WEN;
        let CTRL_HUM_REG  = OSRSH;
        
        super.viewDidLoad()
        
        // Konashiが使用可能になった時に呼び出される。
        Konashi.shared().readyHandler = {
            // i2cモード設定　思いの外時間がかかる
            Konashi.i2cMode(KonashiI2CMode.enable100K)
            Thread.sleep(forTimeInterval: 0.1)
            print("config set")
            
            // BME280の読み込み設定を書き込み
            self.i2cWrite(uData: UInt8(CTRL_HUM_REG), address: 0xF2)
            self.i2cWrite(uData: UInt8(CTRL_MEAS_REG), address: 0xF4)
            self.i2cWrite(uData: UInt8(CONFIG_REG), address: 0xF5)
            
            // キャリブレーション用の値を取得
            // http://www.ne.jp/asahi/o-family/extdisk/BME280/BME280_DJP.pdf
            self.i2cWrite(uData: 0x88)
            self.i2cReadRequest(readLength: 8)
            
            self.i2cWrite(uData: 0x90)
            self.i2cReadRequest(readLength: 8)
            
            self.i2cWrite(uData: 0x98)
            self.i2cReadRequest(readLength: 8)
            
            self.i2cWrite(uData: 0xA1)
            self.i2cReadRequest(readLength: 1)

            self.i2cWrite(uData: 0xE1)
            self.i2cReadRequest(readLength: 7)
            
            // 気温・気圧・湿度をくださいリクエスト
            self.i2cWrite(uData: 0xF7)
            self.i2cReadRequest(readLength: 8)
        }
        
        Konashi.shared()?.i2cReadCompleteHandler = {[weak self] (data) -> Void in
            // ReadDataの準備が整うとこのハンドラに入る。
            // 複数のReadDataを一つのハンドラで管理するためswitchで処理する
            
            guard let self = self else { return }
            guard let data = data else {return}
            
            switch self.readSequenceCount {
            case 0:
                self.datas = self.datas + data[0...7]
                self.readSequenceCount += 1
                break
            case 1:
                self.datas = self.datas + data[0...7]
                self.readSequenceCount += 1
                break
            case 2:
                self.datas = self.datas + data[0...7]
                self.readSequenceCount += 1
                break
            case 3:
                self.datas = self.datas + [data[0]]
                self.readSequenceCount += 1
                break
            case 4:
                self.datas = self.datas + data[0...6]
                self.readSequenceCount += 1
                
                let d = self.datas
                
                // 全てのデータが揃ったら操作しやすいように配列に格納
                self.digT1 = (UInt16(d[1]) << 8) | UInt16(d[0])
                self.digT2 = (Int16(d[3]) << 8) | Int16(d[2])
                self.digT3 = (Int16(d[5]) << 8) | Int16(d[4])
                self.digP1 = (UInt16(d[7]) << 8) | UInt16(d[6])
                self.digP2 = (Int16(d[9]) << 8) | Int16(d[8])
                self.digP3 = (Int16(d[11]) << 8) | Int16(d[10])
                self.digP4 = (Int16(d[13]) << 8) | Int16(d[12])
                self.digP5 = (Int16(d[15]) << 8) | Int16(d[14])
                self.digP6 = (Int16(d[17]) << 8) | Int16(d[16])
                self.digP7 = (Int16(d[19]) << 8) | Int16(d[18])
                self.digP8 = (Int16(d[21]) << 8) | Int16(d[20])
                self.digP9 = (Int16(d[23]) << 8) | Int16(d[22])
                self.digH1 = Int8(d[24])
                self.digH2 = (Int16(d[26]) << 8) | Int16(d[25])
                self.digH3 = Int8(d[27])
                self.digH4 = (Int16(d[28]) << 4) | (0x0F & Int16(d[29]))
                self.digH5 = (Int16(d[30]) << 4) | ((Int16(d[29]) >> 4) & 0x0F)
                self.digH6 = Int8(d[31]);
                break
                
            case 5:
                var environmentData = [Int]()
                //UInt8でくるのでキャリブレーション用にIntにキャスト
                environmentData = data[0...7].map{Int($0)}
                
                let presRaw = (environmentData[0] << 12) | (environmentData[1] << 4) | (environmentData[2] >> 4)
                let tempRaw = ((environmentData[3] << 12) | (environmentData[4] << 4) | (environmentData[5] >> 4))
                let humRaw  = ((environmentData[6] << 8) | environmentData[7])
                
                print("raw value : ", presRaw, tempRaw, humRaw)
                
                // キャリブレーションをかける。
                let tempCal = Double(self.calibratedT(tempRaw)) / 100.0
                let presCal = Double(self.calibratedP(Int32(presRaw))) / 100.0
                let humCal = Double(self.calibrationH(humRaw)) / 1024.0
                
                print("気温 :", tempCal)
                print("気圧 :", presCal)
                print("湿度 :", humCal)
                
                self.readSequenceCount = 0
                self.datas.removeAll()
                break
            default:
                break
            }
        }
    }
    
    func calibratedT(_ rawT: Int) -> Int {
        var var1: Int
        var var2: Int
        var T: Int
        var1 = ((((rawT >> 3) - (Int(digT1) << 1))) * (Int(digT2))) >> 11;
        
        // 計算式が複雑すぎるとコンパイラに怒られるので分割する
        let tmp1: Int = ((rawT >> 4) - Int(digT1)) * ((rawT >> 4) - Int(digT1))
        let tmp2: Int = tmp1 >> 12
        var2 = (tmp2 * Int(digT3)) >> 14;
        tFine = var1 + var2;
        
        T = (tFine * 5 + 128) >> 8;
        return T;
    }
    

    func calibratedP(_ rawP: Int32) -> UInt32 {
        
        var var1: Int32
        var var2: Int32
        var P: UInt32
        
        var1 = ((Int32(tFine))>>1) - Int32(64000);
        
        var2 = (((var1 >> 2) * (var1 >> 2)) >> 11) * (Int32(digP6));
        var2 = var2 + ((var1 * (Int32(digP5))) << 1);
        var2 = (var2 >> 2) + ((Int32(digP4)) << 16);
        let tmp1 = ((Int32(digP3) * (((var1 >> 2) * (var1 >> 2)) >> 13)) >> 3)
        var1 = (tmp1 + (((Int32(digP2)) * var1)>>1)) >> 18;
        
        var1 = ((((32768 + var1)) * (Int32(digP1)))>>15);
        if (var1 == 0) {
            return 0;
        }
        
        P = ((UInt32(((Int32(1048576) - rawP)) - (var2 >> 12)))) * 3125;
        
        if(P < 0x80000000) {
            P = (P << 1) / (UInt32(var1));
        } else {
            P = (P / UInt32(var1)) * 2;
        }
        
        var1 = ((Int32(digP9)) * (Int32(((P >> 3) * (P >> 3))>>13))) >> 12;
        var2 = ((Int32(P>>2)) * (Int32(digP8)))>>13;
        
        P = UInt32(Int32(P) + ((var1 + var2 + Int32(digP7)) >> 4));
        return P;
    }

    
    func calibrationH(_ adc_H: Int) -> UInt {
        var vX1: Int
        
        vX1 = (tFine - (76800));
        vX1 = (((((adc_H << 14) - ((Int(digH4)) << 20) - ((Int(digH5)) * vX1)) +
        (16384)) >> 15) * (((((((vX1 * (Int(digH6))) >> 10) *
        (((vX1 * (Int(digH3))) >> 11) + (32768))) >> 10) + (2097152)) *
        (Int(digH2)) + 8192) >> 14));
        vX1 = (vX1 - (((((vX1 >> 15) * (vX1 >> 15)) >> 7) * (Int(digH1))) >> 4));
        vX1 = (vX1 < 0 ? 0 : vX1);
        vX1 = (vX1 > 419430400 ? 419430400 : vX1);
        return UInt(vX1 >> 12);
    }

    
    private func i2cReadRequest(readLength: Int32) {
        Konashi.i2cStartCondition()
        Thread.sleep(forTimeInterval: 0.01)
        Konashi.i2cReadRequest(readLength, address: ADDR_BME280)
        
        Thread.sleep(forTimeInterval: 0.01)
        Konashi.i2cStopCondition()
        Thread.sleep(forTimeInterval: 0.6)
    }
    
    private func i2cWrite(uData: UInt8, address: UInt8? = nil) {
        Konashi.i2cStartCondition()
        Thread.sleep(forTimeInterval: 0.01)
        
        guard let address = address else {
            let data = Data(bytes: [uData])
            Konashi.i2cWrite(data, address: ADDR_BME280)
            Thread.sleep(forTimeInterval: 0.01)
            Konashi.i2cStopCondition()
            return
        }
        
        let data = Data(bytes: [address, uData])
        Konashi.i2cWrite(data, address: ADDR_BME280)
        Thread.sleep(forTimeInterval: 0.01)
        Konashi.i2cStopCondition()
    }
    
    private func i2cWrite(data: String, address: UInt8) {
        Konashi.i2cStartCondition()
        Konashi.i2cWrite(data, address: address)
        Konashi.i2cStopCondition()
    }
    
    private func i2cRead(address: UInt8, requestByte: Int32) -> Data? {
        Konashi.i2cStartCondition()
        
        Konashi.i2cReadRequest(requestByte, address: address)
        
        Konashi.i2cStopCondition()
        
        return Konashi.i2cReadData()
    }

    @IBAction func konashiFind(_ sender: Any) {
        Konashi.find()
    }
    
    @IBAction func readButtonDidPush(_ sender: Any) {
        self.i2cWrite(uData: 0x88)
        self.i2cReadRequest(readLength: 8)
        
        self.i2cWrite(uData: 0x90)
        self.i2cReadRequest(readLength: 8)
        
        self.i2cWrite(uData: 0x98)
        self.i2cReadRequest(readLength: 8)
        
        self.i2cWrite(uData: 0xA1)
        self.i2cReadRequest(readLength: 1)
        
        self.i2cWrite(uData: 0xE1)
        self.i2cReadRequest(readLength: 7)
        
        self.i2cWrite(uData: 0xF7)
        self.i2cReadRequest(readLength: 8)
    }
    
}

