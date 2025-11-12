enum FunnelStage {
  addressSearch,
  brokerDiscovery,
  quoteRequest,
  quoteResponse,
  selection,
}

extension FunnelStageKey on FunnelStage {
  String get key => toString().split('.').last;
}

/// Centralised analytics event names to avoid typos.
class AnalyticsEventNames {
  AnalyticsEventNames._();

  // Address search funnel
  static const String addressSearchStarted = 'address_search_started';
  static const String addressSearchCompleted = 'address_search_completed';
  static const String addressSelected = 'address_selected';

  // Broker discovery
  static const String navigateBrokerSearch = 'navigate_broker_search';
  static const String brokerListOpened = 'broker_list_opened';
  static const String brokerListLoaded = 'broker_list_loaded';
  static const String brokerListLoadFailed = 'broker_list_load_failed';
  static const String brokerListFilterApplied = 'broker_list_filter_applied';
  static const String frequentBrokersLoaded = 'frequent_brokers_loaded';
  static const String frequentBrokersFailed = 'frequent_brokers_failed';

  // Quote requests
  static const String quoteRequestBulkAuto = 'quote_request_bulk_auto';
  static const String quoteRequestBulkManual = 'quote_request_bulk_manual';
  static const String quoteRequestBulkCancelled = 'quote_request_bulk_cancelled';
  static const String quoteRequestSubmitted = 'quote_request_submitted';
  static const String quoteRequestSubmitFailed = 'quote_request_submit_failed';

  // Quote response / selection
  static const String quoteHistoryOpened = 'quote_history_opened';
  static const String quoteHistoryFilterApplied = 'quote_history_filter_applied';
  static const String quoteDetailViewed = 'quote_detail_viewed';
  static const String quoteComparisonShortcutTapped = 'quote_comparison_shortcut_tapped';
  static const String quoteComparisonShortcutEmpty = 'quote_comparison_shortcut_empty';
  static const String quoteComparisonOpened = 'quote_comparison_opened';
  static const String quoteComparisonPageOpened = 'quote_comparison_page_opened';

  // Guest conversion
  static const String guestLoginCtaTapped = 'guest_login_cta_tapped';
  static const String guestLoginSkip = 'guest_login_skip';
  static const String guestLoginQuoteHistoryCta = 'guest_login_quote_history_cta';
}

