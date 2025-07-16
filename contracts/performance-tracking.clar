;; Performance Tracking Contract
;; Monitors portfolio performance metrics

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-INPUT (err u401))
(define-constant ERR-RECORD-NOT-FOUND (err u402))
(define-constant ERR-INSUFFICIENT-DATA (err u403))

;; Data Variables
(define-data-var next-record-id uint u1)

;; Data Maps
(define-map performance-records
  uint
  {
    portfolio-id: uint,
    period-start: uint,
    period-end: uint,
    starting-value: uint,
    ending-value: uint,
    total-return: int,
    annualized-return: int,
    recorded-at: uint,
    recorder: principal
  }
)

(define-map portfolio-metrics
  uint
  {
    total-records: uint,
    best-return: int,
    worst-return: int,
    average-return: int,
    volatility: uint,
    sharpe-ratio: int
  }
)

(define-map monthly-returns
  { portfolio-id: uint, month: uint, year: uint }
  int
)

;; Public Functions

;; Record performance data
(define-public (record-performance
  (portfolio-id uint)
  (period-start uint)
  (period-end uint)
  (starting-value uint)
  (ending-value uint))
  (let ((record-id (var-get next-record-id))
        (total-return (calculate-return starting-value ending-value))
        (annualized-return (annualize-return total-return (- period-end period-start))))

    (asserts! (> starting-value u0) ERR-INVALID-INPUT)
    (asserts! (> ending-value u0) ERR-INVALID-INPUT)
    (asserts! (> period-end period-start) ERR-INVALID-INPUT)

    (map-set performance-records record-id
      {
        portfolio-id: portfolio-id,
        period-start: period-start,
        period-end: period-end,
        starting-value: starting-value,
        ending-value: ending-value,
        total-return: total-return,
        annualized-return: annualized-return,
        recorded-at: block-height,
        recorder: tx-sender
      }
    )

    (update-portfolio-metrics portfolio-id total-return)
    (var-set next-record-id (+ record-id u1))

    (ok record-id)
  )
)

;; Record monthly return
(define-public (record-monthly-return (portfolio-id uint) (month uint) (year uint) (return int))
  (begin
    (asserts! (and (>= month u1) (<= month u12)) ERR-INVALID-INPUT)
    (asserts! (> year u2020) ERR-INVALID-INPUT)

    (map-set monthly-returns
      { portfolio-id: portfolio-id, month: month, year: year }
      return
    )

    (ok true)
  )
)

;; Update portfolio metrics
(define-public (calculate-portfolio-metrics (portfolio-id uint))
  (let ((current-metrics (default-to
          { total-records: u0, best-return: 0, worst-return: 0,
            average-return: 0, volatility: u0, sharpe-ratio: 0 }
          (map-get? portfolio-metrics portfolio-id))))

    ;; This would typically aggregate all records for the portfolio
    ;; For simplicity, we'll update with placeholder calculations
    (map-set portfolio-metrics portfolio-id
      (merge current-metrics {
        total-records: (+ (get total-records current-metrics) u1)
      })
    )

    (ok true)
  )
)

;; Batch record multiple performance entries
(define-public (batch-record-performance
  (records (list 20 {portfolio-id: uint, start: uint, end: uint, start-val: uint, end-val: uint})))
  (let ((results (map record-single-performance records)))
    (ok results)
  )
)

;; Private Functions

;; Calculate return percentage
(define-private (calculate-return (starting-value uint) (ending-value uint))
  (let ((difference (if (>= ending-value starting-value)
                       (- ending-value starting-value)
                       (- starting-value ending-value)))
        (percentage (/ (* difference u100) starting-value)))
    (if (>= ending-value starting-value)
        (to-int percentage)
        (- (to-int percentage))
    )
  )
)

;; Annualize return based on period
(define-private (annualize-return (total-return int) (period-blocks uint))
  (let ((annual-blocks u52560)) ;; Approximate blocks per year
    (if (> period-blocks u0)
        (/ (* total-return (to-int annual-blocks)) (to-int period-blocks))
        total-return
    )
  )
)

;; Update portfolio metrics with new return
(define-private (update-portfolio-metrics (portfolio-id uint) (new-return int))
  (let ((current-metrics (default-to
          { total-records: u0, best-return: 0, worst-return: 0,
            average-return: 0, volatility: u0, sharpe-ratio: 0 }
          (map-get? portfolio-metrics portfolio-id))))

    (map-set portfolio-metrics portfolio-id
      {
        total-records: (+ (get total-records current-metrics) u1),
        best-return: (if (> new-return (get best-return current-metrics))
                        new-return
                        (get best-return current-metrics)),
        worst-return: (if (< new-return (get worst-return current-metrics))
                         new-return
                         (get worst-return current-metrics)),
        average-return: (/ (+ (* (get average-return current-metrics)
                                (to-int (get total-records current-metrics)))
                             new-return)
                          (to-int (+ (get total-records current-metrics) u1))),
        volatility: (get volatility current-metrics),
        sharpe-ratio: (get sharpe-ratio current-metrics)
      }
    )
  )
)

;; Record single performance entry
(define-private (record-single-performance
  (data {portfolio-id: uint, start: uint, end: uint, start-val: uint, end-val: uint}))
  (unwrap-panic (record-performance
    (get portfolio-id data)
    (get start data)
    (get end data)
    (get start-val data)
    (get end-val data)
  ))
)

;; Read-only Functions

;; Get performance record
(define-read-only (get-performance-record (record-id uint))
  (map-get? performance-records record-id)
)

;; Get portfolio metrics
(define-read-only (get-portfolio-metrics (portfolio-id uint))
  (map-get? portfolio-metrics portfolio-id)
)

;; Get monthly return
(define-read-only (get-monthly-return (portfolio-id uint) (month uint) (year uint))
  (map-get? monthly-returns { portfolio-id: portfolio-id, month: month, year: year })
)

;; Calculate compound annual growth rate
(define-read-only (calculate-cagr (starting-value uint) (ending-value uint) (years uint))
  (if (and (> starting-value u0) (> ending-value u0) (> years u0))
      (let ((growth-ratio (/ ending-value starting-value))
            (power-factor (/ u100 years)))
        ;; Simplified CAGR calculation
        (- (* growth-ratio power-factor) u100)
      )
      u0
  )
)

;; Get performance summary
(define-read-only (get-performance-summary (portfolio-id uint))
  (let ((metrics (map-get? portfolio-metrics portfolio-id)))
    (match metrics
      data {
        total-records: (get total-records data),
        best-return: (get best-return data),
        worst-return: (get worst-return data),
        average-return: (get average-return data)
      }
      { total-records: u0, best-return: 0, worst-return: 0, average-return: 0 }
    )
  )
)
