const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const DB_FILE = path.join(__dirname, 'db.json');
const INITIAL_DB_FILE = path.join(__dirname, 'initial_db.json');

app.use(cors());
app.use(express.json());

// Load or initialize persistent database
function loadDatabase() {
  if (!fs.existsSync(DB_FILE)) {
    const initialData = fs.readFileSync(INITIAL_DB_FILE, 'utf-8');
    fs.writeFileSync(DB_FILE, initialData, 'utf-8');
  }
  return JSON.parse(fs.readFileSync(DB_FILE, 'utf-8'));
}

function saveDatabase(data) {
  fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2), 'utf-8');
}

// Active Mock Scenario Control
// Scenarios: 'NORMAL', 'SLOW', 'TIMEOUT_AFTER_SAVE', 'SERVER_ERROR', 'DUPLICATE_ATTENDANCE_CONFLICT', 'LEAVE_VALIDATION_REJECTION'
let currentScenario = process.env.MOCK_SCENARIO || 'NORMAL';

// Office Location & Geofence
const OFFICE_LAT = 28.6139;
const OFFICE_LNG = 77.2090;
const MAX_DISTANCE_METERS = 200.0;
const COMPANY_TIMEZONE = 'Asia/Kolkata';

// Haversine distance formula
function calculateDistanceInMeters(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Earth radius in metres
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
  const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

// Extract company working date (YYYY-MM-DD) in COMPANY_TIMEZONE
function getCompanyWorkingDate(isoTimestamp) {
  const date = new Date(isoTimestamp);
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: COMPANY_TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(date);
}

// Current company date
function getCurrentCompanyDate() {
  return getCompanyWorkingDate(new Date().toISOString());
}

// Middleware: Mock Scenarios & Delays
app.use(async (req, res, next) => {
  // Allow scenario control endpoints to bypass scenario interceptor
  if (req.path.startsWith('/mock-control')) {
    return next();
  }

  // 1. Server Error Scenario
  if (currentScenario === 'SERVER_ERROR') {
    return res.status(500).json({
      success: false,
      message: 'Internal server error (simulated by MOCK_SCENARIO=SERVER_ERROR)',
    });
  }

  // 2. Slow Response Scenario
  if (currentScenario === 'SLOW') {
    await new Promise((resolve) => setTimeout(resolve, 3000));
  }

  next();
});

// --- Mock Control Endpoints ---

// GET /mock-control/scenario
app.get('/mock-control/scenario', (req, res) => {
  res.json({
    currentScenario,
    availableScenarios: [
      'NORMAL',
      'SLOW',
      'TIMEOUT_AFTER_SAVE',
      'SERVER_ERROR',
      'DUPLICATE_ATTENDANCE_CONFLICT',
      'LEAVE_VALIDATION_REJECTION',
    ],
  });
});

// POST /mock-control/scenario { scenario: "SLOW" }
app.post('/mock-control/scenario', (req, res) => {
  const { scenario } = req.body;
  if (!scenario) {
    return res.status(400).json({ success: false, message: 'Scenario name is required' });
  }
  currentScenario = scenario;
  console.log(`[Mock Control] Scenario switched to: ${currentScenario}`);
  res.json({ success: true, message: `Scenario set to ${currentScenario}` });
});

// POST /mock-control/reset
app.post('/mock-control/reset', (req, res) => {
  const initialData = fs.readFileSync(INITIAL_DB_FILE, 'utf-8');
  fs.writeFileSync(DB_FILE, initialData, 'utf-8');
  currentScenario = 'NORMAL';
  console.log('[Mock Control] Database and scenario reset to initial default state');
  res.json({ success: true, message: 'Database reset to initial defaults.' });
});

// --- HRMS API Endpoints (Prefix /api/v1) ---

const apiRouter = express.Router();

// 1. GET /employee/me
apiRouter.get('/employee/me', (req, res) => {
  const db = loadDatabase();
  res.json({
    success: true,
    data: db.employee,
  });
});

// 2. GET /attendance?month=YYYY-MM
apiRouter.get('/attendance', (req, res) => {
  const { month } = req.query; // e.g. "2026-11"
  const db = loadDatabase();
  let records = db.attendance_records || [];

  if (month) {
    records = records.filter((r) => r.working_date.startsWith(month));
  }

  res.json({
    success: true,
    data: records,
  });
});

// 3. POST /attendance/events
apiRouter.post('/attendance/events', async (req, res) => {
  const { eventId, employeeId, eventType, timestamp, latitude, longitude } = req.body;

  // Basic payload validation
  if (!eventId || !employeeId || !eventType || !timestamp || latitude == null || longitude == null) {
    return res.status(400).json({
      success: false,
      message: 'Missing required fields: eventId, employeeId, eventType, timestamp, latitude, longitude',
    });
  }

  const normalizedEventType = eventType.toUpperCase();
  if (normalizedEventType !== 'CHECK_IN' && normalizedEventType !== 'CHECK_OUT') {
    return res.status(422).json({
      success: false,
      message: 'Invalid eventType. Allowed values: CHECK_IN, CHECK_OUT',
    });
  }

  const db = loadDatabase();

  // Scenario 5: Duplicate Attendance Conflict Simulation
  if (currentScenario === 'DUPLICATE_ATTENDANCE_CONFLICT') {
    return res.status(409).json({
      success: false,
      message: 'Simulated conflict: Check-in record already registered for this employee today.',
      conflictType: 'DUPLICATE_RECORD',
    });
  }

  // --- Idempotency Check using eventId ---
  if (db.attendance_events && db.attendance_events[eventId]) {
    const existing = db.attendance_events[eventId];
    // Check if the payload is identical
    const isPayloadMatch =
      existing.employeeId === employeeId &&
      existing.eventType === normalizedEventType &&
      existing.timestamp === timestamp &&
      Math.abs(existing.latitude - latitude) < 0.0001 &&
      Math.abs(existing.longitude - longitude) < 0.0001;

    if (isPayloadMatch) {
      console.log(`[Idempotent Hit] Event ${eventId} replayed. Returning existing result.`);
      return res.status(200).json({
        success: true,
        message: 'Idempotent request recognized. Returning existing saved record.',
        isIdempotentRetry: true,
        data: existing.response,
      });
    } else {
      // Reused eventId with DIFFERENT payload
      return res.status(409).json({
        success: false,
        message: 'Conflict: Reused eventId with differing event payload.',
        conflictType: 'IDEMPOTENCY_KEY_MISMATCH',
      });
    }
  }

  // Geofence Validation: office distance must be within 200m
  const distance = calculateDistanceInMeters(
    latitude,
    longitude,
    Number(db.employee.office_latitude),
    Number(db.employee.office_longitude)
  );
  if (distance > MAX_DISTANCE_METERS) {
    return res.status(422).json({
      success: false,
      message: `Location outside allowed office perimeter (${Math.round(distance)}m > ${MAX_DISTANCE_METERS}m)`,
      rejectionReason: 'GEOFENCE_VIOLATION',
      distanceMeters: Math.round(distance),
    });
  }

  const workingDate = getCompanyWorkingDate(timestamp);
  let record = db.attendance_records.find(
    (r) => r.employee_id === employeeId && r.working_date === workingDate
  );

  let updatedRecord;

  if (normalizedEventType === 'CHECK_IN') {
    // Only one check-in per employee per company working day
    if (record && record.check_in_timestamp) {
      return res.status(409).json({
        success: false,
        message: `Employee ${employeeId} has already checked in on working date ${workingDate}`,
        conflictType: 'ALREADY_CHECKED_IN',
      });
    }

    if (!record) {
      record = {
        id: `ATT-${Date.now()}`,
        employee_id: employeeId,
        working_date: workingDate,
        check_in_timestamp: timestamp,
        check_out_timestamp: null,
        attendance_status: 'Present',
      };
      db.attendance_records.push(record);
    } else {
      record.check_in_timestamp = timestamp;
      record.attendance_status = 'Present';
    }
    updatedRecord = record;
  } else if (normalizedEventType === 'CHECK_OUT') {
    // Check-out only allowed after check-in
    if (!record || !record.check_in_timestamp) {
      return res.status(422).json({
        success: false,
        message: `Cannot check out before checking in on working date ${workingDate}`,
        rejectionReason: 'NO_CHECK_IN_FOUND',
      });
    }

    // Correct ordering between check-in and check-out
    if (new Date(timestamp) < new Date(record.check_in_timestamp)) {
      return res.status(422).json({
        success: false,
        message: 'Check-out timestamp cannot be earlier than check-in timestamp',
        rejectionReason: 'INVALID_EVENT_ORDER',
      });
    }

    record.check_out_timestamp = timestamp;
    updatedRecord = record;
  }

  // Save event in idempotency table
  db.attendance_events[eventId] = {
    employeeId,
    eventType: normalizedEventType,
    timestamp,
    latitude,
    longitude,
    response: updatedRecord,
  };

  saveDatabase(db);

  // Scenario 3: Request Timeout After Server Has Saved The Event
  if (currentScenario === 'TIMEOUT_AFTER_SAVE') {
    console.log(`[Scenario: TIMEOUT_AFTER_SAVE] Event ${eventId} saved. Delaying response for 12 seconds...`);
    await new Promise((resolve) => setTimeout(resolve, 12000));
  }

  res.status(200).json({
    success: true,
    message: `${normalizedEventType} successfully processed`,
    data: updatedRecord,
  });
});

// 4. GET /leave/balance
apiRouter.get('/leave/balance', (req, res) => {
  const db = loadDatabase();
  res.json({
    success: true,
    data: db.leave_balance,
  });
});

// 5. GET /leave/requests
apiRouter.get('/leave/requests', (req, res) => {
  const db = loadDatabase();
  res.json({
    success: true,
    data: db.leave_requests || [],
  });
});

// 6. POST /leave/requests
apiRouter.post('/leave/requests', (req, res) => {
  const { employeeId, leaveType, startDate, endDate, reason } = req.body;

  // Scenario 6: Force Leave Validation Rejection
  if (currentScenario === 'LEAVE_VALIDATION_REJECTION') {
    return res.status(422).json({
      success: false,
      message: 'Simulated leave validation error (MOCK_SCENARIO=LEAVE_VALIDATION_REJECTION)',
      errors: ['Simulated policy rejection: Annual blackout period active.'],
    });
  }

  const errors = [];

  // Required checks
  if (!employeeId) errors.push('employeeId is required');
  if (!leaveType) errors.push('leaveType is required');
  if (!startDate) errors.push('startDate is required');
  if (!endDate) errors.push('endDate is required');

  // Reason must contain at least 10 non-whitespace characters
  if (!reason || reason.trim().length < 10) {
    errors.push('Reason must contain at least 10 non-whitespace characters');
  }

  // Only Casual and Sick leave types
  const normalizedType = leaveType ? leaveType.charAt(0).toUpperCase() + leaveType.slice(1).toLowerCase() : '';
  if (normalizedType !== 'Casual' && normalizedType !== 'Sick') {
    errors.push('Invalid leave type. Only "Casual" or "Sick" are allowed');
  }

  const currentCompanyDate = getCurrentCompanyDate();

  // Start date cannot be before current company date
  if (startDate && startDate < currentCompanyDate) {
    errors.push(`Start date (${startDate}) cannot be before current company date (${currentCompanyDate})`);
  }

  // End date cannot be before start date
  if (startDate && endDate && endDate < startDate) {
    errors.push(`End date (${endDate}) cannot be before start date (${startDate})`);
  }

  if (errors.length > 0) {
    return res.status(422).json({
      success: false,
      message: 'Validation failed',
      errors,
    });
  }

  const db = loadDatabase();

  // Check overlapping with existing Pending or Approved leave requests
  const existingRequests = db.leave_requests || [];
  const hasOverlap = existingRequests.some((r) => {
    if (r.employee_id !== employeeId || (r.status !== 'Pending' && r.status !== 'Approved')) {
      return false;
    }
    // Date overlap condition: (StartA <= EndB) and (EndA >= StartB)
    return startDate <= r.end_date && endDate >= r.start_date;
  });

  if (hasOverlap) {
    return res.status(422).json({
      success: false,
      message: 'Requested dates overlap with an existing Pending or Approved leave application',
      errors: ['Dates overlap with an existing leave request'],
    });
  }

  // Calculate calendar days (count all calendar days including weekends)
  const dStart = new Date(startDate);
  const dEnd = new Date(endDate);
  const diffTime = Math.abs(dEnd - dStart);
  const requestedDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;

  // Check available balance
  const balance = db.leave_balance;
  const available = normalizedType === 'Casual' ? balance.casual_leave : balance.sick_leave;

  if (requestedDays > available) {
    return res.status(422).json({
      success: false,
      message: `Requested ${requestedDays} days exceeds available ${normalizedType} leave balance of ${available}`,
      errors: [`Insufficient ${normalizedType} leave balance`],
    });
  }

  // Deduct from balance
  if (normalizedType === 'Casual') {
    balance.casual_leave -= requestedDays;
  } else {
    balance.sick_leave -= requestedDays;
  }
  balance.total_available_leave = balance.casual_leave + balance.sick_leave;

  // Create new request
  const newLeave = {
    id: `LV-${Date.now()}`,
    employee_id: employeeId,
    leave_type: normalizedType,
    start_date: startDate,
    end_date: endDate,
    reason: reason.trim(),
    status: 'Pending',
  };

  db.leave_requests.push(newLeave);
  saveDatabase(db);

  res.status(201).json({
    success: true,
    message: 'Leave request submitted successfully',
    data: newLeave,
  });
});

app.use('/api/v1', apiRouter);

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`===============================================`);
  console.log(`REBS HRMS Mock Server listening on port ${PORT}`);
  console.log(`Base URL: http://0.0.0.0:${PORT}/api/v1`);
  console.log(`Active Scenario: ${currentScenario}`);
  console.log(`===============================================`);
});

