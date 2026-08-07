// TemplateStore.swift
// HaispaceRuntime — Core/Capabilities/Editing
//
// Menyimpan definisi template dan slot berdasarkan manifest terbaru.

import Foundation

@MainActor
public class TemplateStore: ObservableObject {
    public static let shared = TemplateStore()
    
    @Published public private(set) var templates: [TemplateManifest] = []
    
    private let storageURL: URL
    
    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.storageURL = docs.appendingPathComponent("templates_store.json")
        loadFromDisk()
    }
    
    public func ingest(templates: [TemplateManifest]) {
        self.templates = templates
        saveToDisk()
        
        // Forensic Logging sesuai permintaan
        HaispaceLogger.info("[TemplateStore] Ingested \(templates.count) templates.", category: "template")
        for template in templates {
            HaispaceLogger.info("[TemplateStore] Template ID: \(template.id), Name: \(template.name)", category: "template")
            HaispaceLogger.info("[TemplateStore] Canvas: \(template.canvas.width)x\(template.canvas.height), FrameAssetId: \(template.frameAssetId)", category: "template")
            HaispaceLogger.info("[TemplateStore] Slots count: \(template.slots.count)", category: "template")
            for slot in template.slots {
                HaispaceLogger.info("[TemplateStore] Slot \(slot.index): x:\(slot.x), y:\(slot.y), w:\(slot.width), h:\(slot.height), rot:\(slot.rotation), fit:\(slot.fit)", category: "template")
            }
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(templates)
            try data.write(to: storageURL)
        } catch {
            HaispaceLogger.error("[TemplateStore] Failed to save to disk: \(error.localizedDescription)", category: "template")
        }
    }
    
    private func loadFromDisk() {
        do {
            if FileManager.default.fileExists(atPath: storageURL.path) {
                let data = try Data(contentsOf: storageURL)
                self.templates = try JSONDecoder().decode([TemplateManifest].self, from: data)
                HaispaceLogger.info("[TemplateStore] Loaded \(self.templates.count) templates from disk.", category: "template")
            }
        } catch {
            HaispaceLogger.error("[TemplateStore] Failed to load from disk: \(error.localizedDescription)", category: "template")
        }
    }
}
