//
//  CountryDetector.swift
//  BabyTracker
//
//  Best guess at the country whose vaccine schedule to show, with NO location
//  permission.
//
//  Order is deliberate: IP geolocation first, because it catches the common
//  case of a family living abroad on a local SIM or Wi-Fi, then the device
//  region as an instant fallback. The device guess renders immediately and the
//  IP result refines it when the network answers - see
//  `VaccineStore.refineCountryFromIP()`.
//
//  An explicit pick by the parent always wins; that is what VAX_COUNTRY_USER
//  guards. Android resolves this with TelephonyManager, which iOS has no
//  permission-free equivalent for, so the device region is as far as the
//  offline path goes.
//

import Foundation

enum CountryDetector {

    /// Android falls back to Saudi Arabia, and so do we - the largest slice of
    /// this app's audience.
    static let fallback = "SAU"

    // MARK: - Offline

    /// The device's region as ISO-3, or the fallback. Synchronous and free.
    static func deviceGuess(in data: VaccineData) -> String {
        guard
            let region = Locale.current.region?.identifier,
            let iso3 = alpha3(forAlpha2: region),
            data.contains(iso3)
        else { return fallback }
        return iso3
    }

    // MARK: - IP geolocation

    /// ISO-3 for the device's public IP, or nil. No permission needed, and a
    /// failure is silent on purpose: this only ever refines an already-usable
    /// guess, so there is nothing to report to the parent.
    static func fromIP(in data: VaccineData) async -> String? {
        guard let url = URL(string: "https://api.country.is/") else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.5
        request.cachePolicy = .reloadIgnoringLocalCacheData

        guard
            let (bytes, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse, http.statusCode == 200,
            let payload = try? JSONDecoder().decode(IPResponse.self, from: bytes),
            let iso3 = alpha3(forAlpha2: payload.country),
            data.contains(iso3)
        else { return nil }

        return iso3
    }

    private struct IPResponse: Decodable {
        let country: String
    }

    // MARK: - ISO-3166 alpha-2 to alpha-3

    /// Foundation exposes no alpha-3 lookup (Java's `Locale.getISO3Country()`
    /// has no counterpart), so the mapping is carried here. Generated from the
    /// official ISO 3166-1 list and filtered to the countries that actually
    /// appear in vaccines.json, so anything outside the bundled data simply
    /// misses and falls through to the fallback.
    static func alpha3(forAlpha2 code: String) -> String? {
        alpha2ToAlpha3[code.uppercased()]
    }

    private static let alpha2ToAlpha3: [String: String] = {
        var map: [String: String] = [:]
        map.reserveCapacity(184)
        // The literal is wrapped across lines for readability, so each half
        // is trimmed rather than used raw.
        for pair in packedPairs.split(separator: ",") {
            let parts = pair.split(separator: ":")
            guard parts.count == 2 else { continue }
            let alpha2 = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let alpha3 = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard alpha2.count == 2, alpha3.count == 3 else { continue }
            map[alpha2] = alpha3
        }
        return map
    }()

    private static let packedPairs = """
        AE:ARE,AF:AFG,AG:ATG,AI:AIA,AM:ARM,AO:AGO,AR:ARG,AT:AUT,
        AU:AUS,AZ:AZE,BA:BIH,BB:BRB,BD:BGD,BE:BEL,BF:BFA,BG:BGR,
        BH:BHR,BI:BDI,BJ:BEN,BM:BMU,BO:BOL,BR:BRA,BS:BHS,BT:BTN,
        BW:BWA,BY:BLR,BZ:BLZ,CA:CAN,CD:COD,CF:CAF,CG:COG,CH:CHE,
        CI:CIV,CL:CHL,CM:CMR,CN:CHN,CO:COL,CR:CRI,CU:CUB,CV:CPV,
        CY:CYP,DE:DEU,DJ:DJI,DK:DNK,DM:DMA,DZ:DZA,EC:ECU,EG:EGY,
        ER:ERI,ES:ESP,ET:ETH,FI:FIN,FJ:FJI,FR:FRA,GA:GAB,GB:GBR,
        GD:GRD,GE:GEO,GH:GHA,GM:GMB,GN:GIN,GQ:GNQ,GR:GRC,GT:GTM,
        GU:GUM,GW:GNB,GY:GUY,HK:HKG,HN:HND,HT:HTI,HU:HUN,ID:IDN,
        IE:IRL,IN:IND,IQ:IRQ,IR:IRN,IS:ISL,IT:ITA,JM:JAM,JO:JOR,
        KE:KEN,KG:KGZ,KI:KIR,KM:COM,KN:KNA,KR:KOR,KW:KWT,KY:CYM,
        LA:LAO,LB:LBN,LC:LCA,LK:LKA,LR:LBR,LS:LSO,LT:LTU,LU:LUX,
        LV:LVA,LY:LBY,MA:MAR,MC:MCO,MD:MDA,ME:MNE,MG:MDG,MH:MHL,
        ML:MLI,MM:MMR,MN:MNG,MO:MAC,MP:MNP,MR:MRT,MS:MSR,MT:MLT,
        MV:MDV,MW:MWI,MX:MEX,MY:MYS,MZ:MOZ,NA:NAM,NE:NER,NG:NGA,
        NI:NIC,NL:NLD,NP:NPL,NZ:NZL,OM:OMN,PA:PAN,PE:PER,PF:PYF,
        PG:PNG,PH:PHL,PK:PAK,PL:POL,PS:PSE,PT:PRT,PY:PRY,QA:QAT,
        RS:SRB,RU:RUS,RW:RWA,SA:SAU,SB:SLB,SC:SYC,SD:SDN,SE:SWE,
        SG:SGP,SI:SVN,SK:SVK,SL:SLE,SM:SMR,SN:SEN,SO:SOM,SR:SUR,
        SS:SSD,ST:STP,SV:SLV,SY:SYR,SZ:SWZ,TC:TCA,TD:TCD,TG:TGO,
        TJ:TJK,TK:TKL,TL:TLS,TM:TKM,TN:TUN,TO:TON,TR:TUR,TT:TTO,
        TV:TUV,TZ:TZA,UG:UGA,US:USA,UY:URY,UZ:UZB,VC:VCT,VE:VEN,
        VG:VGB,VN:VNM,VU:VUT,WS:WSM,YE:YEM,ZA:ZAF,ZM:ZMB,ZW:ZWE,
        """
}
