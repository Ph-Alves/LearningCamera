//
//  ContentView.swift
//  LearningCameraApp
//
//  Created by Paulo Henrique Costa Alves on 05/04/26.
//

import SwiftUI
import AVFoundation
import CoreML
import Combine

// COMO CRIAR UMA CAMERA NO SEU APP
// 1- Peça permissão com o AVCaptureDevice.requestAcess e verifique o status
// OBS: Coloque no info.plist a permissão
// 2- Depois configure sua câmera com AVCaptureSession
// 3- Prepare o input e o output, definindo o delegate em uma classe que conforme.
// 4- commit e start running na mesma classe de configuração
// 5- Monte sua UIView com AVCaptureVideoPreviewLayer
// 6- Converta para view no swiftUI (precisa de uma session (configurada)
// 7- Jogue seu conversor de UIView (CameraPreview) no body da view do swiftUI
// 8- E o response do captureService jogue em um text inferior.


// SOBRE O FLUXO
/// O app pede permissão, com .requestAcess e caso o usuário aceite, ele configura a câmera, passando um capture session e uma camera que é configurada na propria instância dela.
/// Para a função de configurar, precisamos de um session preset que .high é para video, caso fosse photo seria um .photo, e ai precisamos de um input e um output
/// Em um video normal, com gravação e tal, seria um output diferente, o que estamos usando aqui é para ser compativel com o modelo que analisará o que está sendo visto, o videoDataOutput pega frame a frame e entrega para o modelo com o capture output
/// Antes de adicionar o nosso output, precisamos definir um delegate que vai receber esses valores, e ai sim podemos adicionar nosso output
/// Lembre-se que no input e output sempre deve vir uma verificação para saber se pode adicionar.
/// Depois de montar a função de configurar, você pode colocar isso em uma classe que já conforma com o delegate e já preparar uma função que ele mesmo te fornece que é o capture output, nela, você vai fazer uma verificação do pixelBuffer e passar ele para o seu modelo fazer a predição
/// Salva a predição em uma variável da classe, e puxa ela na sua view.
/// Um ponto importante e que a sua UIView, precisa de  um valor para a preview layer, e por isso você passa a propria session configurada para ela na sua struct que converte ela para UIKit.
struct ContentView: View {
    
    // MARK: - Variables
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    let captureSession = AVCaptureSession()
    @State var captureService = CaptureService()
    let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    
    // MARK: - Body View
    var body: some View {
        VStack {
            CameraPreview(session: captureSession)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                Text(captureService.prediction?.target ?? "Analisando...")
            }
        }
        .padding()
        .onAppear {
            // Caso não tenha aceitado, peça acesso.
            if status == .notDetermined {
                Task {
                    await AVCaptureDevice.requestAccess(for: .video)
                }
            } else if status == .authorized {
                captureService.configureCamera(captureSession: captureSession, camera: camera)
            }
        }
    }
}

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    init(session: AVCaptureSession) {
        self.session = session
    }
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

@Observable
class CaptureService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let model = try! MyImageClassifierAdesivo_5()
    var prediction: MyImageClassifierAdesivo_5Output?
    
    func configureCamera(captureSession: AVCaptureSession, camera: AVCaptureDevice?) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        do {
            // O input é a conexão do hardware com a session, recebendo os dados
            let input = try AVCaptureDeviceInput(device: camera!)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            // O output é a externalização disso, como ele vai retornar, o que vai retornar, o que vai sair da session.
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            
            let processingQueue = DispatchQueue(label: "videoProcessing")
            output.setSampleBufferDelegate(self, queue: processingQueue)
            
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
            }
            captureSession.commitConfiguration()
            captureSession.startRunning()
        } catch {
            print("erro: \(error)")
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        self.prediction = try! model.prediction(image: pixelBuffer)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
