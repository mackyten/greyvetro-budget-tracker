import 'package:intl/intl.dart';

final currencyFormat = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
final monthFormat = DateFormat('MMMM yyyy');
final percentFormat = NumberFormat.percentPattern('en_PH');
