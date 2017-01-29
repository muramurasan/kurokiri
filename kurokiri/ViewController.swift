//
//  ViewController.swift
//  kurokiri
//
//  Created by MATSUMURAYASUHIRO on 2017/01/28.
//  Copyright © 2017年 Yasuhiro Matsumura. All rights reserved.
//

import UIKit
import CoreLocation
import CoreBluetooth
import AVFoundation

class ViewController: UIViewController, CLLocationManagerDelegate, CBPeripheralManagerDelegate {
    @IBOutlet var message_label: UILabel!
    @IBOutlet var number_field: UITextField!
    @IBOutlet var call_button: UIButton!
    private var se_hai : AVAudioPlayer?
    private var se_pinpon : AVAudioPlayer?
    private var searched:Bool!
    var interval_timer: Timer!

    // ペリフェラル
    var myPheripheralManager:CBPeripheralManager!

    // スキャナー(セントラル)
    var myLocationManager:CLLocationManager!
    var myBeaconRegion:CLBeaconRegion!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let soundFilePath1 : NSString = Bundle.main.path(forResource: "hai", ofType: "mp3")! as NSString
        let fileURL1 : NSURL = NSURL(fileURLWithPath: soundFilePath1 as String)
        let soundFilePath2 : NSString = Bundle.main.path(forResource: "pinpon", ofType: "mp3")! as NSString
        let fileURL2 : NSURL = NSURL(fileURLWithPath: soundFilePath2 as String)
        do {
            se_hai = try AVAudioPlayer(contentsOf: fileURL1 as URL, fileTypeHint: nil)
            se_pinpon = try AVAudioPlayer(contentsOf: fileURL2 as URL, fileTypeHint: nil)
        } catch {
        }
        prepareAdvertise()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func callAction() {
        // 数字入力のキーボードをしまう
        view.endEditing(true)
        
        let tmpStr = number_field.text! as NSString
        if (tmpStr.length != 4){
            message_label.text = "番号は4桁で入力してください"
            return
        }
        
        call_button.isEnabled = false
        startAdvertise()
    }

    // --------------------------------------------------------------------------
    //
    // ペリフェラルとしての処理
    // 参考：http://docs.fabo.io/swift/corelocation/002_ibeacon_advertising.html
    //
    // --------------------------------------------------------------------------

    func prepareAdvertise() {
        // PeripheralManagerを定義.
        myPheripheralManager = CBPeripheralManager()
        myPheripheralManager.delegate = self
    }
    
    // Peripheralの準備ができたら呼び出される.
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("peripheralManagerDidUpdateState")
        message_label.text = "お客様番号下4桁を入力してください"
        call_button.isEnabled = true
    }
    
    func startAdvertise() {
        // iBeaconのUUID.
        let myProximityUUID = NSUUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAA" + number_field.text!)
        
        // iBeaconのIdentifier.
        let myIdentifier = "call"
        
        // Major.
        let myMajor : CLBeaconMajorValue = 0
        
        // Minor.
        let myMinor : CLBeaconMinorValue = 0
        
        // BeaconRegionを定義.
        let myBeaconRegion = CLBeaconRegion(proximityUUID: myProximityUUID! as UUID, major: myMajor, minor: myMinor, identifier: myIdentifier)
        
        // Advertisingのフォーマットを作成.
        let myBeaconPeripheralData = NSDictionary(dictionary: myBeaconRegion.peripheralData(withMeasuredPower: nil))
        
        // Advertisingを発信.
        myPheripheralManager.startAdvertising(myBeaconPeripheralData as? [String : AnyObject])
        
        message_label.text = "呼び出し準備中です……"
    }
    
    // Advertisingが始まると呼ばれる.
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("peripheralManagerDidStartAdvertising")
        
        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(timeUpAdvertise), userInfo: nil, repeats: false)
    }
    
    func timeUpAdvertise() {
        myPheripheralManager.stopAdvertising()
        startBeaconScan()
        se_pinpon!.play()
        message_label.text = "呼び出しをしています……"
    }

    
    // --------------------------------------------------------------------------
    // 
    // スキャナー(セントラル)としての処理
    // 参考：http://docs.fabo.io/swift/corelocation/003_ibeacon_monitaring.html
    //
    // --------------------------------------------------------------------------
    
    func startBeaconScan() {
        // ロケーションマネージャの作成.
        myLocationManager = CLLocationManager()
        
        // デリゲートを自身に設定.
        myLocationManager.delegate = self
        
        // 取得精度の設定.
        myLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // 取得頻度の設定.(1mごとに位置情報取得)
        myLocationManager.distanceFilter = 1
        
        // セキュリティ認証のステータスを取得
        let status = CLLocationManager.authorizationStatus()
        print("CLAuthorizedStatus: \(status.rawValue)");
        
        // まだ認証が得られていない場合は、認証ダイアログを表示
        if(status == .notDetermined) {
            // [認証手順1] まだ承認が得られていない場合は、認証ダイアログを表示.
            // [認証手順2] が呼び出される
            myLocationManager.requestAlwaysAuthorization()
        }
    }
    
    // [認証手順2] 認証のステータスがかわったら呼び出される.
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("didChangeAuthorizationStatus");
        
        // 認証のステータスをログで表示
        switch (status) {
        case .notDetermined:
            print("未認証の状態")
            break
        case .restricted:
            print("制限された状態")
            break
        case .denied:
            print("許可しない")
            break
        case .authorizedAlways:
            print("常に許可")
            // 許可がある場合はiBeacon検出を開始.
            startMyMonitoring()
            break
        case .authorizedWhenInUse:
            print("このAppの使用中のみ許可")
            // 許可がある場合はiBeacon検出を開始.
            startMyMonitoring()
            break
        }
    }
    
    // [iBeacon 手順2]  startMyMonitoring()内のでstartMonitoringForRegionが正常に開始されると呼び出される。
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("[iBeacon 手順2] didStartMonitoringForRegion");
        
        // [iBeacon 手順3] この時点でビーコンがすでにRegion内に入っている可能性があるので、その問い合わせを行う
        // [iBeacon 手順4] がDelegateで呼び出される.
        manager.requestState(for: region);
        
        // 1秒毎にrequestStateを呼ぶタイマーの開始
        if(interval_timer == nil) {
            interval_timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(fireRequestState), userInfo: nil, repeats: true)
        }
    }
    
    // [iBeacon 手順4] 現在リージョン内にiBeaconが存在するかどうかの通知を受け取る.
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        print("[iBeacon 手順4] locationManager: didDetermineState \(state)")
        
        switch (state) {
            
        case .inside: // リージョン内にiBeaconが存在いる
            print("iBeaconが存在!");
            
            // [iBeacon 手順5] すでに入っている場合は、そのままiBeaconのRangingをスタートさせる。
            // [iBeacon 手順6] がDelegateで呼び出される.
            // iBeaconがなくなったら、Rangingを停止する
            manager.startRangingBeacons(in: region as! CLBeaconRegion)
            break;
            
        case .outside:
            print("iBeaconが圏外!")
            break;
            
        case .unknown:
            print("iBeaconが圏外もしくは不明な状態!")
            break;
        }
    }
    
    /*
     [iBeacon 手順6] 現在取得しているiBeacon情報一覧が取得できる.
     */
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        if(beacons.count > 0){
            
            // STEP7: 発見したBeaconの数だけLoopをまわす
            for i in 0 ..< beacons.count {
                let beacon = beacons[i]
                print("UUID: \(beacon.proximityUUID)")
                
                let replyUUID = UUID.init(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBB" + number_field.text!)
                let absenceUUID = UUID.init(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCC" + number_field.text!)
                
                if(beacon.proximityUUID == replyUUID){
                    searched = true
                    resetParameter()
                    message_label.text = "在宅中です"
                    se_hai!.play()
                    manager.stopRangingBeacons(in: region)
                    return
                } else if(beacon.proximityUUID == absenceUUID) {
                    searched = true
                    resetParameter()
                    message_label.text = "不在の可能性があります"
                    manager.stopRangingBeacons(in: region)
                    return
                } else {
                    searched = true
                    resetParameter()
                    message_label.text = "通信エラー：不明な信号"
                    manager.stopRangingBeacons(in: region)
                    return
                }
            }
        }
    }
    
    func startMyMonitoring() {
        let UUIDList = [
            "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBB" + number_field.text!,
            "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCC" + number_field.text!
        ]
        let identifierList = [
            "reply",
            "absence"
        ]
        
        for i in 0 ..< UUIDList.count {
            // BeaconのUUIDを設定.
            let uuid: NSUUID! = NSUUID(uuidString: "\(UUIDList[i].lowercased())")
            
            // BeaconのIfentifierを設定.
            let identifierStr: String = "\(identifierList[i])"
            
            // リージョンを作成.
            myBeaconRegion = CLBeaconRegion(proximityUUID: uuid as UUID, identifier: identifierStr)
            
            // ディスプレイがOnの時だけイベントが通知されるように設定.
            myBeaconRegion.notifyEntryStateOnDisplay = true
            
            // 入域通知の設定.
            myBeaconRegion.notifyOnEntry = true
            
            // 退域通知の設定.
            myBeaconRegion.notifyOnExit = false
            
            // [iBeacon 手順1] iBeaconのモニタリング開始([iBeacon 手順2]がDelegateで呼び出される).
            myLocationManager.startMonitoring(for: myBeaconRegion)
        }
        
        searched = false
        Timer.scheduledTimer(timeInterval: 10.0, target: self, selector: #selector(timeUpScan), userInfo: nil, repeats: false)
    }
    
    func fireRequestState() {
        myLocationManager.requestState(for: myBeaconRegion);
    }
    
    func timeUpScan() {
        if (!searched) {
            resetParameter()
            message_label.text = "インターホンが見つかりませんでした"
            myLocationManager.stopRangingBeacons(in: myBeaconRegion)
        }
    }
    
    func resetParameter() {
        call_button.isEnabled = true
        if(interval_timer != nil){
            interval_timer.invalidate()
            interval_timer = nil
        }
    }
}

