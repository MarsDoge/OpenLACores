#ifndef LA_COMMON_UART_H
#define LA_COMMON_UART_H

#include <stdint.h>

#include "la_config.h"

/* 16550-style UART register offsets used by the optional UART driver. */
#define LA_UART_RBR 0x00U
#define LA_UART_THR 0x00U
#define LA_UART_DLL 0x00U
#define LA_UART_IER 0x01U
#define LA_UART_DLH 0x01U
#define LA_UART_IIR 0x02U
#define LA_UART_FCR 0x02U
#define LA_UART_LCR 0x03U
#define LA_UART_MCR 0x04U
#define LA_UART_LSR 0x05U
#define LA_UART_MSR 0x06U
#define LA_UART_USR 0x1fU

typedef enum {
    LA_UART_STOPBIT_1,
    LA_UART_STOPBIT_2
} la_uart_stopbit_t;

typedef enum {
    LA_UART_PARITY_NONE,
    LA_UART_PARITY_ODD,
    LA_UART_PARITY_EVEN
} la_uart_parity_t;

typedef enum {
    LA_UART_WORDSIZE_5,
    LA_UART_WORDSIZE_6,
    LA_UART_WORDSIZE_7,
    LA_UART_WORDSIZE_8
} la_uart_wordsize_t;

typedef enum {
    LA_UART_DISABLE,
    LA_UART_ENABLE
} la_uart_mode_t;

typedef struct {
    uint32_t baudrate;
    la_uart_stopbit_t stopbit;
    la_uart_parity_t parity;
    la_uart_wordsize_t wordsize;
    la_uart_mode_t rxmode;
    la_uart_mode_t txmode;
} la_uart_config_t;

typedef struct {
    /* register_map is uintptr_t so the same driver builds for LA32 and LA64. */
    uint32_t uart_id;
    uintptr_t register_map;
    uint32_t baudrate;
    la_uart_parity_t parity;
    la_uart_stopbit_t stopbit;
    la_uart_wordsize_t wordsize;
    la_uart_mode_t rxmode;
    la_uart_mode_t txmode;
} la_uart_device_t;

uint32_t la_uart_open(la_uart_device_t *uart, uint32_t id);
uint32_t la_uart_close(la_uart_device_t *uart);
uint32_t la_uart_init(la_uart_device_t *uart, const la_uart_config_t *config);
uint32_t la_uart_putc(la_uart_device_t *uart, uint8_t c);
uint32_t la_uart_status(la_uart_device_t *uart);

#endif
