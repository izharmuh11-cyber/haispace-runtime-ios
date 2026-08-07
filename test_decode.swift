import Foundation

public struct TemplateManifest: Codable, Equatable {
    public let id: String
    public let name: String
    public let canvas: Canvas
    public let coordinateSystem: CoordinateSystem
    public let frameAssetId: String
    public let slots: [Slot]
    
    public struct Canvas: Codable, Equatable {
        public let width: Double
        public let height: Double
    }
    
    public struct CoordinateSystem: Codable, Equatable {
        public let origin: String
        public let unit: String
    }
    
    public struct Slot: Codable, Equatable {
        public let id: String
        public let index: Int
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double
        public let rotation: Double
        public let borderRadius: Double
        public let fit: String
    }
}

public struct CloudAssetDTO: Codable {
    public let assetId: String
    public let name: String
    public let role: String
    public let downloadUrl: String
    public let checksum: String
    public let mimeType: String
    public let version: Int
}

public struct EventRuntimeResponse: Codable {
    public let manifestId: String
    public let version: Int
    public let eventId: String
    public let eventName: String
    public let publishedAt: String?
    public let assets: [CloudAssetDTO]?
    public let templates: [TemplateManifest]?
}

let jsonString = """
{
  "manifestId": "91885a3b-c1af-44de-b98a-56fc3d50539b",
  "version": 1,
  "eventId": "1b169abf-e5e0-4b74-8fa3-55b6f9eab8e5",
  "eventName": "R2 Infrastructure Test Event",
  "publishedAt": "2026-08-07T07:27:24.189Z",
  "assets": [
    {
      "assetId": "837c860e-81da-4340-b28d-282e4341ce44",
      "name": "Real 4K Frame Overlay R2",
      "role": "frame",
      "downloadUrl": "https://api.haispaceproject.my.id/v1/assets/raw/organizations/org_haispace_r2/assets/837c860e-81da-4340-b28d-282e4341ce44/real_r2_frame.png",
      "checksum": "b53d60a8b947347d40c8358a8dcee06bceb89c1248e949a991c37cd0005933b5",
      "mimeType": "image/png",
      "version": 4
    }
  ],
  "templates": [
    {
      "id": "834813c0-ad49-4a4e-88e4-d26a14ca803d",
      "name": "Pink and White Creative Romantic Photostrip Photo Collage (2)",
      "canvas": {
        "width": 2667,
        "height": 4000
      },
      "coordinateSystem": {
        "origin": "top-left",
        "unit": "pixel"
      },
      "frameAssetId": "837c860e-81da-4340-b28d-282e4341ce44",
      "slots": [
        {
          "id": "356cad7a-27f9-4136-b9c8-bec89a2cb683",
          "index": 0,
          "x": 517,
          "y": 311,
          "width": 859,
          "height": 776,
          "rotation": -4,
          "borderRadius": 0,
          "fit": "cover"
        },
        {
          "id": "a44d65cc-6dad-4b29-b9a1-dbd74bd9cbe5",
          "index": 1,
          "x": 1262,
          "y": 633,
          "width": 860,
          "height": 776,
          "rotation": 4,
          "borderRadius": 0,
          "fit": "cover"
        },
        {
          "id": "1db418c7-6834-4773-88e1-e7ee574ebc60",
          "index": 2,
          "x": 429,
          "y": 1418,
          "width": 860,
          "height": 775,
          "rotation": 5,
          "borderRadius": 0,
          "fit": "cover"
        },
        {
          "id": "3a959132-84a2-4c2a-8663-a13242a01aed",
          "index": 3,
          "x": 1192,
          "y": 1757,
          "width": 862,
          "height": 778,
          "rotation": -12,
          "borderRadius": 0,
          "fit": "cover"
        },
        {
          "id": "8be2bba8-8855-49df-b32a-250ea3feebc1",
          "index": 4,
          "x": 435,
          "y": 2393,
          "width": 858,
          "height": 774,
          "rotation": -3,
          "borderRadius": 0,
          "fit": "cover"
        },
        {
          "id": "36843218-07b8-4443-ad07-45cb9f7fd4b3",
          "index": 5,
          "x": 1346,
          "y": 2725,
          "width": 858,
          "height": 773,
          "rotation": 14,
          "borderRadius": 0,
          "fit": "cover"
        }
      ]
    }
  ]
}
"""

let data = jsonString.data(using: .utf8)!
let decoder = JSONDecoder()
do {
    let response = try decoder.decode(EventRuntimeResponse.self, from: data)
    print("✅ DECODE SUCCESS")
    print("--------------------------------------------------")
    
    if let templates = response.templates {
        print("[TemplateStore] Ingested \(templates.count) templates.")
        for template in templates {
            print("[TemplateStore] Template ID: \(template.id), Name: \(template.name)")
            print("[TemplateStore] Canvas: \(template.canvas.width)x\(template.canvas.height), FrameAssetId: \(template.frameAssetId)")
            print("[TemplateStore] Slots count: \(template.slots.count)")
            for slot in template.slots {
                print("[TemplateStore] Slot \(slot.index): x:\(slot.x), y:\(slot.y), w:\(slot.width), h:\(slot.height), rot:\(slot.rotation), fit:\(slot.fit)")
            }
        }
    } else {
        print("❌ NO TEMPLATES FOUND IN RESPONSE")
    }
} catch {
    print("❌ DECODE FAILED: \(error)")
}
