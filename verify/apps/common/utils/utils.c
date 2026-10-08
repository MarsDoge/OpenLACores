#include "printf.h"

/* Default exception callback used by the startup exception vector. */
void enter_expt() {
  printf("\nI am in EXPT Mode!\n\n");
}

/* Default user-mode callback kept for compatibility with older tests. */
void enter_user() {
  printf("\nI am in User Mode!\n\n");
}
