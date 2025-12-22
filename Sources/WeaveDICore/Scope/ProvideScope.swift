//
//  ProvideScope.swift
//  WeaveDI
//
//  Created by Codex on 2025-03-??.
//

/// Lifetime options for dependency registrations.
public enum ProvideScope: String, Sendable {
  case transient
  case singleton
}
