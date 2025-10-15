import time
import threading
from datetime import datetime
import asyncio
from bleak import BleakScanner, BLEDevice, AdvertisementData

# 匯入 QR Code 產生流程 (假設 generate_qrcode.py 包含 main_workflow)
from generate_qrcode import main_workflow, ACCESS_TOKEN

# --- 【必須設定】目標裝置和 REF 值 ---
# 設藥局 BLE MAC ADDRESS = TARGET_ADDRESS
TARGET_ADDRESS = "66:4d:e5:cd:e9:b0"
RSSI_THRESHOLD = -50
# 設藥局 REF VALUE = "00000000_iristest"
REF_VALUE = "00000000_iristest" 

# 使用狀態變數來追蹤流程，只有當狀態從 False 變為 True 時才觸發
last_near = False  

def ble_callback(device: BLEDevice, advertisement_data: AdvertisementData):
    """
    Bleak 掃描器回調函數：處理偵測到的 BLE 裝置資訊。
    實現邏輯：只在從 '遠' 轉 '近' 的瞬間觸發一次 QR Code 產生流程。
    """
    global last_near
    
    # 將偵測到的地址轉換成大寫以利比對
    detected_mac = device.address.upper()
    
    # 檢查 MAC 地址是否符合目標
    if detected_mac == TARGET_ADDRESS.upper():
        rssi = advertisement_data.rssi
        
        # 顯示偵測到的裝置資訊，幫助除錯
        print(f"[BLE] {device.name if device.name else 'None'} RSSI={rssi}")
        
        if rssi is not None:
            
            # --- 1. 偵測到從 '遠' 轉換為 '近' 的邊緣 (觸發點) ---
            if rssi > RSSI_THRESHOLD and not last_near:
                
                # 設置狀態鎖，防止重複觸發
                last_near = True 
                
                print(f"[觸發 NEAR] MAC {device.address} 距離夠近 (RSSI={rssi})，強制使用 ref: {REF_VALUE} 產生 QR Code！")

                # 呼叫 QR Code 產生流程
                main_workflow(REF_VALUE) 
                
            # --- 2. 偵測到從 '近' 轉換為 '遠' 的邊緣 (重置點) ---
            elif rssi <= RSSI_THRESHOLD and last_near:
                
                # 裝置距離夠遠，重設狀態鎖，允許下一次靠近時觸發
                last_near = False
                print(f"[重置 FAR] MAC {device.address} 距離變遠 (RSSI={rssi})，已重設狀態。")
                
            # --- 3. 裝置持續在 near/far 區域，不執行任何動作 ---


async def ble_scan_loop():
    """主掃描迴圈，啟動 Bleak 掃描器"""
    scanner = BleakScanner(detection_callback=ble_callback)
    await scanner.start()
    print("BLE 掃描啟動，靠近目標裝置會自動產生 QR Code。Ctrl+C 結束。")
    try:
        # 主迴圈保持運行，等待回調函數輸出結果
        while True:
            await asyncio.sleep(1) 
    finally:
        await scanner.stop()

if __name__ == "__main__":
    try:
        asyncio.run(ble_scan_loop())
    except KeyboardInterrupt:
        print("\n程式已手動停止。")
    except Exception as e:
        print(f"程式運行期間發生錯誤: {e}")