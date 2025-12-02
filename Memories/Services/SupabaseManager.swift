import Foundation
import Supabase

// Rimuoviamo l'enum Constants hardcodato e usiamo Secrets.swift
// Nota: Devi creare un file 'Secrets.swift' (aggiunto al .gitignore) con le chiavi.

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        // Ora leggiamo le chiavi dalla struct Secrets che risiede nel file ignorato da Git
        self.client = SupabaseClient(
            supabaseURL: URL(string: Secrets.supabaseUrl)!,
            supabaseKey: Secrets.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true // Questo risolve il warning giallo
                )
            )
        )
    }
}
