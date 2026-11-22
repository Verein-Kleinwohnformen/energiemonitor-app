/// Kalendertag ohne Uhrzeit (Lokalzeit).
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Ganze Kalendertage von [from] bis [to]. Rechnet in UTC, damit die
/// Zeitumstellung (23- oder 25-Stunden-Tag) keinen Tag verschluckt.
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;
