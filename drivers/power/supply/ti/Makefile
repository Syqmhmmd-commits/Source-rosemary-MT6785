obj-$(CONFIG_LN8000_CHARGE_PUMP)    += ln8000_charger.o
obj-$(CONFIG_BQ2597X_CHARGE_PUMP)   += bq2597x_charger.o pd_policy_manager.o cp_qc30.o

CFLAGS_bq2597x_charger.o   := -O1 -fno-strict-aliasing -fno-delete-null-pointer-checks
CFLAGS_pd_policy_manager.o := -O1 -fno-strict-aliasing -fno-delete-null-pointer-checks
CFLAGS_cp_qc30.o           := -O1 -fno-strict-aliasing -fno-delete-null-pointer-checks
