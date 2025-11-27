const Map<String, dynamic> ts_option = {
  "default": {
    "date": {
      "minOffsetDays": 0,
      "maxOffsetDays": 10,
      "allowPast": false,
    },
    "startTime": {
      "unitMinutes": 5,
      "businessStart": "dynamic",
      "businessEnd": "dynamic",
      "allowBeforeNow": false,
      "lastReservable": "dynamic",
    },
    "duration": {
      "min": 30,
      "max": 180,
      "unit": 5,
      "mustEndBeforeBusinessEnd": true,
      "autoAdjustOnInput": true,
    },
    "ts": {
      "onlyAvailable": true,
      "allowedSlots": {
        "1": true,
        "2": true,
        "3": false,
        "4": true,
        "5": true,
        "6": true,
        "7": true,
        "8": true,
        "9": true,
      },
    },
    "payment": {
      "methods": {
        "credit": true,
        "card": true,
        "welfare": false,
      },
      "memberDiscountOnlyCredit": true,
    },
    "discount": {
      "member": true,
      "membership": true,
      "intensive": true,
      "revisit": true,
      "junior_parent": true
    },
  },
  "일반회원": {
    "date": {
      "minOffsetDays": 0,
      "maxOffsetDays": 10,
      "allowPast": false,
    },
    "startTime": {
      "unitMinutes": 5,
      "businessStart": "dynamic",
      "businessEnd": "dynamic",
      "allowBeforeNow": false,
      "lastReservable": "dynamic",
    },
    "duration": {
      "min": 30,
      "max": 180,
      "unit": 5,
      "mustEndBeforeBusinessEnd": true,
      "autoAdjustOnInput": true,
    },
    "ts": {
      "onlyAvailable": true,
      "allowedSlots": {
        "1": true,
        "2": true,
        "3": false,
        "4": true,
        "5": true,
        "6": true,
        "7": true,
        "8": true,
        "9": true,
      },
    },
    "payment": {
      "methods": {
        "credit": true,
        "card": true,
        "welfare": false,
      },
      "memberDiscountOnlyCredit": true,
    },
    "discount": {
      "member": true,
      "membership": true,
      "intensive": true,
      "revisit": true,
      "junior_parent": true
    },
  },
  "주니어": {
    "date": {
      "minOffsetDays": 0,
      "maxOffsetDays": 10,
      "allowPast": false,
    },
    "startTime": {
      "unitMinutes": 10,
      "businessStart": "dynamic",
      "businessEnd": "dynamic",
      "allowBeforeNow": false,
      "lastReservable": "dynamic",
    },
    "duration": {
      "min": 55,
      "max": 55,
      "unit": 55,
      "mustEndBeforeBusinessEnd": true,
      "autoAdjustOnInput": true,
    },
    "ts": {
      "onlyAvailable": true,
      "allowedSlots": {
        "1": false,
        "2": false,
        "3": false,
        "4": false,
        "5": false,
        "6": false,
        "7": true,
        "8": true,
        "9": true,
      },
    },
    "payment": {
      "methods": {
        "credit": true,
        "card": true,
        "welfare": false,
      },
      "memberDiscountOnlyCredit": true,
    },
    "discount": {
      "member": false,
      "membership": false,
      "intensive": false,
      "revisit": false,
      "junior_parent": false
    },
  },
  "아이코젠": {
    "date": {
      "minOffsetDays": 0,
      "maxOffsetDays": 0,
      "allowPast": false,
    },
    "startTime": {
      "unitMinutes": 5,
      "businessStart": "dynamic",
      "businessEnd": "dynamic",
      "allowBeforeNow": false,
      "lastReservable": "dynamic",
      "minAdvanceMinutes": 30,
    },
    "duration": {
      "min": 60,
      "max": 60,
      "unit": 60,
      "mustEndBeforeBusinessEnd": true,
      "autoAdjustOnInput": true,
    },
    "ts": {
      "onlyAvailable": true,
      "allowedSlots": {
        "1": true,
        "2": true,
        "3": true,
        "4": true,
        "5": true,
        "6": true,
        "7": false,
        "8": false,
        "9": false,
      },
    },
    "payment": {
      "methods": {
        "credit": false,
        "card": false,
        "welfare": true,
      },
      "memberDiscountOnlyCredit": true,
    },
    "discount": {
      "member": false,
      "membership": false,
      "intensive": false,
      "revisit": false,
      "junior_parent": false
    },
  },
  "웰빙클럽": {
    "date": {
      "minOffsetDays": 0,
      "maxOffsetDays": 0,
      "allowPast": false,
    },
    "startTime": {
      "unitMinutes": 5,
      "businessStart": "dynamic",
      "businessEnd": "dynamic",
      "allowBeforeNow": false,
      "lastReservable": "dynamic",
      "minAdvanceMinutes": 30,
    },
    "duration": {
      "min": 60,
      "max": 60,
      "unit": 60,
      "mustEndBeforeBusinessEnd": true,
      "autoAdjustOnInput": true,
    },
    "ts": {
      "onlyAvailable": true,
      "allowedSlots": {
        "1": true,
        "2": true,
        "3": true,
        "4": true,
        "5": true,
        "6": true,
        "7": false,
        "8": false,
        "9": false,
      },
    },
    "payment": {
      "methods": {
        "credit": false,
        "card": false,
        "welfare": true,
      },
      "memberDiscountOnlyCredit": true,
    },
    "discount": {
      "member": false,
      "membership": false,
      "intensive": false,
      "revisit": false,
      "junior_parent": false
    },
  },
  "리프레쉬": {
    "date": {
      "minOffsetDays": 0,
      "maxOffsetDays": 0,
      "allowPast": false,
    },
    "startTime": {
      "unitMinutes": 5,
      "businessStart": "dynamic",
      "businessEnd": "dynamic",
      "allowBeforeNow": false,
      "lastReservable": "dynamic",
      "minAdvanceMinutes": 30,
    },
    "duration": {
      "min": 60,
      "max": 60,
      "unit": 60,
      "mustEndBeforeBusinessEnd": true,
      "autoAdjustOnInput": true,
    },
    "ts": {
      "onlyAvailable": true,
      "allowedSlots": {
        "1": true,
        "2": true,
        "3": true,
        "4": true,
        "5": true,
        "6": true,
        "7": false,
        "8": false,
        "9": false,
      },
    },
    "payment": {
      "methods": {
        "credit": false,
        "card": false,
        "welfare": true,
      },
      "memberDiscountOnlyCredit": true,
    },
    "discount": {
      "member": false,
      "membership": false,
      "intensive": false,
      "revisit": false,
      "junior_parent": false
    },
  },
  "김캐디": {
    "date": {
      "minOffsetDays": 0,
      "maxOffsetDays": 0,
      "allowPast": false,
    },
    "startTime": {
      "unitMinutes": 5,
      "businessStart": "dynamic",
      "businessEnd": "dynamic",
      "allowBeforeNow": false,
      "lastReservable": "dynamic",
    },
    "duration": {
      "min": 60,
      "max": 60,
      "unit": 60,
      "mustEndBeforeBusinessEnd": true,
      "autoAdjustOnInput": true,
    },
    "ts": {
      "onlyAvailable": true,
      "allowedSlots": {
        "1": true,
        "2": true,
        "3": true,
        "4": true,
        "5": true,
        "6": true,
        "7": false,
        "8": false,
        "9": false,
      },
    },
    "payment": {
      "methods": {
        "credit": false,
        "card": false,
        "welfare": true,
      },
      "memberDiscountOnlyCredit": true,
    },
    "discount": {
      "member": false,
      "membership": false,
      "intensive": false,
      "revisit": false,
      "junior_parent": false
    },
  },
};
// 각 유형별 옵션은 default를 상속받아 필요시 override해서 사용
// (현재는 모두 default와 동일, 추후 각 유형별로 옵션만 바꿔주면 됨) 