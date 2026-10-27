//
//  ZPLProfile.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// What one printer model understands and how it measures.
///
/// A profile is data. The encoder refuses a command whose capability the profile does not list,
/// converts millimetres with its resolution and keeps widths and speeds within its limits. A
/// profile is only as true as the tests behind it, and ``verification`` says which tests those were.
public struct ZPLProfile: Sendable, Hashable, Identifiable {
    /// How far a profile's claims have been checked.
    public enum Verification: Sendable, Hashable {
        /// A guess kept deliberately small.
        case assumed
        /// Built from the vendor's documentation; not yet tested on the printer.
        case documented
        /// Tested on a physical printer, as described in the note.
        case hardwareTested(String)
    }

    /// The interfaces a model has, as sold and as options.
    public struct Interfaces: Sendable, Hashable {
        /// On every unit of the model.
        public var standard: Set<ZPLInterface>
        /// On some units only, installed at the factory or in the field. A profile cannot tell
        /// whether a given unit has one.
        public var optional: Set<ZPLInterface>

        public init(standard: Set<ZPLInterface>, optional: Set<ZPLInterface> = []) {
            self.standard = standard
            self.optional = optional
        }
    }

    /// A stable identifier, such as `zebra-zd420d-203dpi`. It may be persisted; never rename one.
    public let id: String
    public let name: String
    public let resolution: ZPLResolution
    public let capabilities: ZPLCapabilities
    /// The `^CI` sets the encoder may select.
    public let characterEncodings: Set<ZPLCharacterEncoding>
    /// The set used for a label that names none.
    public let defaultCharacterEncoding: ZPLCharacterEncoding
    /// The widest `^PW` the printhead takes, in dots; also the bound on a field's `x`.
    public let maximumPrintWidth: Int
    /// The longest `^LL`, in dots.
    public let maximumLabelLength: Int
    /// The `^PR` speeds, in inches per second.
    public let printSpeeds: ClosedRange<Int>
    public let interfaces: Interfaces
    public let verification: Verification

    public init(
        id: String,
        name: String,
        resolution: ZPLResolution,
        capabilities: ZPLCapabilities,
        characterEncodings: Set<ZPLCharacterEncoding>,
        defaultCharacterEncoding: ZPLCharacterEncoding,
        maximumPrintWidth: Int,
        maximumLabelLength: Int,
        printSpeeds: ClosedRange<Int>,
        interfaces: Interfaces,
        verification: Verification
    ) {
        precondition(
            characterEncodings.contains(defaultCharacterEncoding),
            "A profile's default character set must be one it lists."
        )
        self.id = id
        self.name = name
        self.resolution = resolution
        self.capabilities = capabilities
        self.characterEncodings = characterEncodings
        self.defaultCharacterEncoding = defaultCharacterEncoding
        self.maximumPrintWidth = maximumPrintWidth
        self.maximumLabelLength = maximumLabelLength
        self.printSpeeds = printSpeeds
        self.interfaces = interfaces
        self.verification = verification
    }

    /// The same model with options installed on this unit, such as ``ZPLCapabilities/cutter``.
    ///
    /// The identifier is kept: it names the model, not the unit. Persist the options next to it.
    public func adding(_ installed: ZPLCapabilities) -> ZPLProfile {
        ZPLProfile(
            id: id,
            name: name,
            resolution: resolution,
            capabilities: capabilities.union(installed),
            characterEncodings: characterEncodings,
            defaultCharacterEncoding: defaultCharacterEncoding,
            maximumPrintWidth: maximumPrintWidth,
            maximumLabelLength: maximumLabelLength,
            printSpeeds: printSpeeds,
            interfaces: interfaces,
            verification: verification
        )
    }

    /// Whether the profile lists this character set.
    public func supports(_ encoding: ZPLCharacterEncoding) -> Bool {
        characterEncodings.contains(encoding)
    }
}
