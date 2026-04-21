#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

BLEServer *pServer = NULL;
BLECharacteristic * pTxCharacteristic;
bool deviceConnected = false;
bool oldDeviceConnected = false;
String receivedData = "";

// UUIDs estándar para el servicio UART por BLE (Nordic UART)
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E" 
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

// Callbacks para gestionar la conexión/desconexión
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("¡Dispositivo BLE conectado!");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Dispositivo BLE desconectado.");
    }
};

// Callbacks para cuando recibimos datos desde el móvil
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String rxValue = pCharacteristic->getValue().c_str();

      if (rxValue.length() > 0) {
        Serial.print("Recibido del móvil: ");
        for (int i = 0; i < rxValue.length(); i++) {
          Serial.print(rxValue[i]);
        }
        Serial.println();
      }
    }
};

void setup() {
  Serial.begin(115200);
  Serial.println("inicio  BT");
     // Inicializamos el dispositivo BLE
  BLEDevice::init("ESP32_S3_BLE");

  // Creamos el servidor BLE
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Creamos el Servicio BLE
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Creamos la característica TX (Para enviar del ESP32 al móvil)
  pTxCharacteristic = pService->createCharacteristic(
										CHARACTERISTIC_UUID_TX,
										BLECharacteristic::PROPERTY_NOTIFY
									);
  pTxCharacteristic->addDescriptor(new BLE2902());

  // Creamos la característica RX (Para recibir del móvil al ESP32)
  BLECharacteristic * pRxCharacteristic = pService->createCharacteristic(
											 CHARACTERISTIC_UUID_RX,
											 BLECharacteristic::PROPERTY_WRITE
										);
  pRxCharacteristic->setCallbacks(new MyCallbacks());

  // Iniciamos el servicio
  pService->start();

  // Empezamos a anunciar (Advertising) para que el móvil nos vea
  pServer->getAdvertising()->start();
  Serial.println("Esperando a que un cliente se conecte por BLE...");
}

void loop() {
  // Leemos del Monitor Serie (PC) y enviamos por BLE (al móvil)
  if (deviceConnected) {
    if (Serial.available()) {
      String txValue = Serial.readStringUntil('\n'); // Leemos hasta darle al Enter
      txValue.trim(); // Limpiamos espacios
      
      if(txValue.length() > 0){
        pTxCharacteristic->setValue(txValue.c_str());
        pTxCharacteristic->notify(); // Enviamos la notificación al móvil
        Serial.print("Enviado al móvil: ");
        Serial.println(txValue);
      }
    }
  }

  // Gestión de reconexión si se desconecta
  if (!deviceConnected && oldDeviceConnected) {
      delay(500); // Dar tiempo a la pila Bluetooth para prepararse
      pServer->startAdvertising(); // Reiniciar publicidad
      Serial.println("Reiniciando anuncio (advertising)...");
      oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
      oldDeviceConnected = deviceConnected;
  }
  delay(20);
}
