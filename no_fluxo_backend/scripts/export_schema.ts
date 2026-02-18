/**
 * Export Database Schema Script
 * 
 * This script exports all tables, views, functions, and triggers from the Supabase database
 * and saves them to a JSON file for documentation and future reference.
 * 
 * Tables and views are discovered dynamically via the Supabase OpenAPI spec,
 * so no hardcoded list is needed.
 * 
 * Run manually: npx ts-node scripts/export_schema.ts
 * Or automatically: runs on backend startup
 */

import { createClient } from '@supabase/supabase-js';
import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

// ESM-compatible __dirname
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

type CliOptions = {
    writeSupabaseMigration: boolean;
    migrationOutDir?: string;
    migrationBasename?: string;
};

function parseCliArgs(argv: string[]): CliOptions {
    const options: CliOptions = {
        writeSupabaseMigration: false
    };

    for (let i = 0; i < argv.length; i++) {
        const arg = argv[i];
        if (arg === '--write-supabase-migration') {
            options.writeSupabaseMigration = true;
        } else if (arg === '--migration-out-dir') {
            options.migrationOutDir = argv[i + 1];
            i++;
        } else if (arg === '--migration-basename') {
            options.migrationBasename = argv[i + 1];
            i++;
        }
    }

    return options;
}

// Load environment variables - try multiple locations
const envPaths = [
    path.join(__dirname, '..', '.env'),
    path.join(__dirname, '..', '..', '.env'),
    '.env'
];

for (const envPath of envPaths) {
    const result = dotenv.config({ path: envPath });
    if (!result.error) {
        console.log(`📁 Loaded .env from: ${envPath}`);
        break;
    }
}

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL || '';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY || '';

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    console.error('❌ Missing Supabase credentials');
    console.error('   Required: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (or SUPABASE_ANON_KEY)');
    console.error('   Checked env vars: SUPABASE_URL, VITE_SUPABASE_URL');
    process.exit(1);
}

console.log('🔌 Connecting to Supabase:', SUPABASE_URL);

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Output file paths
const OUTPUT_DIR = path.join(__dirname, '..', 'docs');
const OUTPUT_FILE = path.join(OUTPUT_DIR, 'database_schema.json');
const OUTPUT_FILE_TABLES = path.join(OUTPUT_DIR, 'database_tables.md');
const OUTPUT_FILE_RLS = path.join(OUTPUT_DIR, 'rls_policies.sql');
const OUTPUT_FILE_FUNCTIONS = path.join(OUTPUT_DIR, 'database_functions.sql');
const OUTPUT_FILE_TRIGGERS = path.join(OUTPUT_DIR, 'database_triggers.sql');

const DEFAULT_MIGRATIONS_OUT_DIR = path.join(OUTPUT_DIR, 'supabase_migrations');
const DEFAULT_MIGRATION_BASENAME = 'latest_init_from_export.sql';

interface DatabaseSchema {
    exported_at: string;
    export_method: string;
    supabase_url: string;
    tables: TableInfo[];
    views: ViewInfo[];
    materialized_views?: MaterializedViewInfo[];
    functions: FunctionInfo[];
    triggers: TriggerInfo[];
    foreign_keys: ForeignKeyInfo[];
    primary_keys: PrimaryKeyInfo[];
    indexes: IndexInfo[];
    policies: PolicyInfo[];
    enums: EnumInfo[];
    table_stats: TableStatInfo[];
}

interface TableInfo {
    table_name: string;
    table_type: string;
    accessible: boolean;
    columns: ColumnInfo[];
    error?: string;
}

interface ColumnInfo {
    column_name: string;
    data_type: string;
    is_nullable?: string;
    column_default?: string | null;
    is_identity?: string;
    ordinal_position?: number;
    is_primary_key?: boolean;
    foreign_key?: {
        foreign_table: string;
        foreign_column: string;
    };
}

interface ViewInfo {
    view_name: string;
    view_definition?: string;
    accessible: boolean;
    columns?: ColumnInfo[];
    error?: string;
}

interface MaterializedViewInfo {
    view_name: string;
    view_definition?: string;
    accessible?: boolean;
    columns?: ColumnInfo[];
    error?: string;
}

interface FunctionInfo {
    function_name: string;
    function_oid?: number;
    return_type: string;
    arguments: string;
    argument_types?: string;
    function_type: string;
    volatility?: string;
    parallel_safety?: string;
    security_definer?: boolean;
    strict?: boolean;
    returns_set?: boolean;
    language?: string;
    source_code?: string;
    definition?: string;
    config?: string[];
    comment?: string;
}

interface TriggerInfo {
    trigger_name: string;
    table_name?: string;
    event_manipulation?: string;
    event_object_table?: string;
    action_timing?: string;
    action_orientation?: string;
    action_statement?: string;
    trigger_type?: string;
    trigger_events?: string;
    for_each?: string;
    trigger_function_name?: string;
    trigger_function_schema?: string;
    trigger_function_definition?: string;
    trigger_function_source?: string;
    trigger_definition?: string;
    is_enabled?: boolean;
    condition?: string;
}

interface ForeignKeyInfo {
    constraint_name: string;
    table_name: string;
    column_name: string;
    foreign_table_name: string;
    foreign_column_name: string;
}

interface PrimaryKeyInfo {
    constraint_name: string;
    table_name: string;
    column_name: string;
}

interface IndexInfo {
    index_name: string;
    table_name: string;
    index_definition: string;
}

interface PolicyInfo {
    policy_name: string;
    table_name: string;
    command: string;
    permissive?: string;
    using_expression?: string | null;
    with_check_expression?: string | null;
}

interface EnumInfo {
    enum_name: string;
    enum_values: string[];
}

interface TableStatInfo {
    table_name: string;
    estimated_rows: number;
    total_size_bytes: number;
}

interface OpenApiSpec {
    paths?: Record<string, unknown>;
    definitions?: Record<string, OpenApiDefinition>;
}

function enrichColumnsWithPrimaryAndForeignKeys(schema: DatabaseSchema): void {
    const pkByTable = new Map<string, Set<string>>();
    for (const pk of schema.primary_keys || []) {
        const set = pkByTable.get(pk.table_name) ?? new Set<string>();
        set.add(pk.column_name);
        pkByTable.set(pk.table_name, set);
    }

    const fkByTableAndColumn = new Map<string, { foreign_table: string; foreign_column: string }>();
    for (const fk of schema.foreign_keys || []) {
        const key = `${fk.table_name}.${fk.column_name}`;
        // If multiple FKs exist for the same column, keep the first.
        if (!fkByTableAndColumn.has(key)) {
            fkByTableAndColumn.set(key, {
                foreign_table: fk.foreign_table_name,
                foreign_column: fk.foreign_column_name
            });
        }
    }

    for (const table of schema.tables || []) {
        const pkCols = pkByTable.get(table.table_name);
        for (const col of table.columns || []) {
            if (pkCols?.has(col.column_name)) {
                col.is_primary_key = true;
            }

            const fk = fkByTableAndColumn.get(`${table.table_name}.${col.column_name}`);
            if (fk) {
                col.foreign_key = {
                    foreign_table: fk.foreign_table,
                    foreign_column: fk.foreign_column
                };
            }
        }
    }
}

interface OpenApiDefinition {
    type?: string;
    properties?: Record<string, OpenApiProperty>;
    required?: string[];
}

interface OpenApiProperty {
    type?: string;
    format?: string;
    description?: string;
    default?: unknown;
    maxLength?: number;
    enum?: string[];
    items?: { type?: string };
}

// Cache for the OpenAPI spec to avoid multiple fetches
let cachedOpenApiSpec: OpenApiSpec | null = null;

/**
 * Fetch and cache the OpenAPI spec from Supabase
 */
async function fetchOpenApiSpec(): Promise<OpenApiSpec | null> {
    if (cachedOpenApiSpec) {
        return cachedOpenApiSpec;
    }

    try {
        const response = await fetch(`${SUPABASE_URL}/rest/v1/`, {
            headers: {
                'apikey': SUPABASE_SERVICE_KEY,
                'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
                // PostgREST returns OpenAPI only when explicitly requested.
                'Accept': 'application/openapi+json'
            }
        });

        if (!response.ok) {
            console.warn(`⚠️ Failed to fetch OpenAPI spec: ${response.status} ${response.statusText}`);
            return null;
        }

        cachedOpenApiSpec = await response.json() as OpenApiSpec;
        return cachedOpenApiSpec;
    } catch (error) {
        console.warn('⚠️ Error fetching OpenAPI spec:', error instanceof Error ? error.message : 'Unknown error');
        return null;
    }
}

/**
 * Discover all tables and views from the Supabase OpenAPI spec
 */
async function discoverTablesAndViews(): Promise<{ tables: string[], views: string[] }> {
    console.log('🔍 Discovering tables and views from OpenAPI spec...');

    try {
        const openApiSpec = await fetchOpenApiSpec();

        if (!openApiSpec) {
            return { tables: [], views: [] };
        }

        // Extract table/view names from the OpenAPI paths
        const paths = openApiSpec.paths || {};
        const allNames = Object.keys(paths)
            .map(path => path.replace(/^\//, '')) // Remove leading slash
            .filter(name => name && !name.includes('/') && !name.startsWith('rpc/')); // Filter out nested paths and RPC

        console.log(`   Found ${allNames.length} endpoints in OpenAPI spec`);

        // We can't easily distinguish tables from views via OpenAPI alone,
        // so we'll try to query each one and categorize based on response
        // For now, return all as potential tables (views are queried the same way)
        return { tables: allNames, views: [] };

    } catch (error) {
        console.warn('⚠️ Error discovering tables:', error instanceof Error ? error.message : 'Unknown error');
        return { tables: [], views: [] };
    }
}

/**
 * Extract column details from OpenAPI definitions, including foreign key info
 */
async function getColumnsFromOpenApi(tableName: string): Promise<ColumnInfo[]> {
    const openApiSpec = await fetchOpenApiSpec();

    if (!openApiSpec || !openApiSpec.definitions) {
        return [];
    }

    const definition = openApiSpec.definitions[tableName];
    if (!definition || !definition.properties) {
        return [];
    }

    const requiredColumns = new Set(definition.required || []);

    return Object.entries(definition.properties).map(([columnName, property], index) => {
        const column: ColumnInfo = {
            column_name: columnName,
            data_type: mapOpenApiTypeToPostgres(property.type, property.format),
            is_nullable: requiredColumns.has(columnName) ? 'NO' : 'YES',
            column_default: property.default !== undefined ? String(property.default) : null,
            ordinal_position: index + 1
        };

        // Detect PK/FK markers from PostgREST OpenAPI descriptions
        const description = property.description || '';

        // Primary key (PostgREST format: "This is a Primary Key.<pk/>")
        if (/Primary Key/i.test(description) || /<pk\/>/i.test(description)) {
            column.is_primary_key = true;
        }

        // Foreign key (PostgREST format: "Foreign Key to `table.column`")
        const fkMatch = description.match(/Foreign Key to [`']?(\w+)\.(\w+)[`']?/i);
        if (fkMatch && fkMatch[1] && fkMatch[2]) {
            column.foreign_key = {
                foreign_table: fkMatch[1],
                foreign_column: fkMatch[2]
            };
        }

        return column;
    });
}

/**
 * Map OpenAPI types to PostgreSQL types
 */
function mapOpenApiTypeToPostgres(type?: string, format?: string): string {
    if (format === 'uuid') return 'uuid';
    if (format === 'date-time' || format === 'timestamp') return 'timestamp with time zone';
    if (format === 'date') return 'date';
    if (format === 'time') return 'time';
    if (format === 'int64' || format === 'bigint') return 'bigint';
    if (format === 'int32') return 'integer';
    if (format === 'double' || format === 'float') return 'double precision';
    if (format === 'json' || format === 'jsonb') return 'jsonb';

    switch (type) {
        case 'integer': return 'integer';
        case 'number': return 'numeric';
        case 'boolean': return 'boolean';
        case 'array': return 'array';
        case 'object': return 'jsonb';
        case 'string': return 'text';
        default: return type || 'unknown';
    }
}

/**
 * Try to get table/view metadata using information_schema via RPC
 */
async function discoverViaInformationSchema(): Promise<{ tables: string[], views: string[] }> {
    console.log('🔍 Trying to discover via information_schema RPC...');

    try {
        // Try calling a custom RPC function to get table info
        const { data, error } = await supabase.rpc('get_table_list');

        if (!error && data) {
            const tables = data.filter((t: any) => t.table_type === 'BASE TABLE').map((t: any) => t.table_name);
            const views = data.filter((t: any) => t.table_type === 'VIEW').map((t: any) => t.table_name);
            console.log(`   Found ${tables.length} tables and ${views.length} views via RPC`);
            return { tables, views };
        }
    } catch (err) {
        // RPC not available, that's fine
    }

    return { tables: [], views: [] };
}

/**
 * Fetch functions from the database using SQL query
 */
async function fetchFunctions(): Promise<FunctionInfo[]> {
    console.log('🔍 Fetching database functions...');

    try {
        // Query to get function definitions from pg_catalog
        const { data, error } = await supabase.rpc('get_public_functions');

        if (error) {
            console.warn('⚠️ get_public_functions RPC not available, trying raw query...');

            // Try a simpler approach - query via raw SQL if RPC not available
            // This requires the function to exist in the database
            return [];
        }

        if (data && Array.isArray(data)) {
            console.log(`   Found ${data.length} functions`);
            return data.map((fn: any) => ({
                function_name: fn.function_name || fn.proname,
                return_type: fn.return_type || fn.rettype || 'unknown',
                arguments: fn.arguments || fn.args || '',
                function_type: fn.function_type || fn.prokind || 'function',
                volatility: fn.volatility || fn.provolatile,
                security_definer: fn.security_definer || fn.prosecdef,
                definition: fn.definition || fn.prosrc
            }));
        }
    } catch (err) {
        console.warn('⚠️ Error fetching functions:', err instanceof Error ? err.message : 'Unknown error');
    }

    return [];
}

/**
 * Try to export using the export_schema RPC function
 */
async function exportViaRPC(): Promise<DatabaseSchema | null> {
    console.log('📊 Trying export_schema RPC function...');

    try {
        const { data, error } = await supabase.rpc('export_schema');

        if (error) {
            console.warn('⚠️ export_schema RPC not available:', error.message);
            console.log('   💡 Run migrations/export_schema_rpc.sql in Supabase SQL Editor to enable full export');
            return null;
        }

        if (data) {
            console.log('✅ Got complete schema via RPC!');
            return {
                ...data,
                export_method: 'rpc',
                supabase_url: SUPABASE_URL.replace(/https?:\/\//, '').split('.')[0] + '.supabase.co'
            } as DatabaseSchema;
        }
    } catch (err) {
        console.warn('⚠️ RPC call failed:', err instanceof Error ? err.message : 'Unknown error');
    }

    return null;
}

/**
 * Export schema by querying tables directly
 */
async function exportViaDirectQueries(): Promise<DatabaseSchema> {
    console.log('📊 Exporting schema via direct table queries...');

    const schema: DatabaseSchema = {
        exported_at: new Date().toISOString(),
        export_method: 'direct_queries',
        supabase_url: SUPABASE_URL.replace(/https?:\/\//, '').split('.')[0] + '.supabase.co',
        tables: [],
        views: [],
        materialized_views: [],
        functions: [],
        triggers: [],
        foreign_keys: [],
        primary_keys: [],
        indexes: [],
        policies: [],
        enums: [],
        table_stats: []
    };

    // First, try to discover tables via information_schema RPC
    let discovered = await discoverViaInformationSchema();

    // If that didn't work, try OpenAPI spec
    if (discovered.tables.length === 0 && discovered.views.length === 0) {
        discovered = await discoverTablesAndViews();
    }

    const allEndpoints = [...new Set([...discovered.tables, ...discovered.views])];

    if (allEndpoints.length === 0) {
        console.warn('⚠️ Could not discover any tables or views');
        console.log('   💡 Make sure your Supabase project has tables exposed via the API');
        return schema;
    }

    console.log(`  📋 Querying ${allEndpoints.length} discovered endpoints...`);

    // Query each discovered endpoint
    for (const endpointName of allEndpoints) {
        process.stdout.write(`     - ${endpointName}... `);
        try {
            const { data, error } = await supabase
                .from(endpointName)
                .select('*')
                .limit(1);

            if (error) {
                console.log('❌');
                // Try to categorize based on error message or add to tables by default
                schema.tables.push({
                    table_name: endpointName,
                    table_type: 'UNKNOWN',
                    accessible: false,
                    columns: [],
                    error: error.message
                });
            } else {
                console.log('✅');

                // Try to get detailed column info from OpenAPI first
                let columns = await getColumnsFromOpenApi(endpointName);

                // Fall back to inferring from data if OpenAPI doesn't have it
                if (columns.length === 0 && data && data.length > 0) {
                    columns = Object.entries(data[0]).map(([key, value], index) => ({
                        column_name: key,
                        data_type: getDataType(value),
                        ordinal_position: index + 1
                    }));
                }

                // If we got table type from information_schema, use it
                const isView = discovered.views.includes(endpointName);

                if (isView) {
                    schema.views.push({
                        view_name: endpointName,
                        accessible: true,
                        columns
                    });
                } else {
                    schema.tables.push({
                        table_name: endpointName,
                        table_type: 'BASE TABLE',
                        accessible: true,
                        columns
                    });
                }
            }
        } catch (err) {
            console.log('❌');
            schema.tables.push({
                table_name: endpointName,
                table_type: 'UNKNOWN',
                accessible: false,
                columns: [],
                error: err instanceof Error ? err.message : 'Unknown error'
            });
        }
    }

    // Derive PKs/FKs embedded in columns
    const fkCount = schema.tables.reduce((count, table) => (
        count + table.columns.filter(col => col.foreign_key).length
    ), 0);
    const pkCount = schema.tables.reduce((count, table) => (
        count + table.columns.filter(col => col.is_primary_key).length
    ), 0);

    // Populate top-level primary_keys for convenience/back-compat
    schema.primary_keys = [];
    for (const table of schema.tables) {
        for (const col of table.columns) {
            if (col.is_primary_key) {
                schema.primary_keys.push({
                    constraint_name: `pk_${table.table_name}`,
                    table_name: table.table_name,
                    column_name: col.column_name
                });
            }
        }
    }

    // Fetch functions
    schema.functions = await fetchFunctions();

    const accessibleTables = schema.tables.filter(t => t.accessible).length;
    const accessibleViews = schema.views.filter(v => v.accessible).length;
    const totalAccessible = accessibleTables + accessibleViews;
    console.log(`  ✅ Found ${totalAccessible}/${allEndpoints.length} accessible endpoints`);
    console.log(`     - ${accessibleTables} tables`);
    console.log(`     - ${accessibleViews} views`);
    console.log(`     - ${schema.functions.length} functions`);
    console.log(`     - ${pkCount} primary keys (embedded in columns)`);
    console.log(`     - ${fkCount} foreign keys (embedded in columns)`);

    return schema;
}

/**
 * Get a more specific data type from a value
 */
function getDataType(value: unknown): string {
    if (value === null) return 'null';
    if (Array.isArray(value)) return 'array';
    if (value instanceof Date) return 'timestamp';
    if (typeof value === 'object') return 'jsonb';
    if (typeof value === 'number') {
        return Number.isInteger(value) ? 'integer' : 'numeric';
    }
    if (typeof value === 'boolean') return 'boolean';
    if (typeof value === 'string') {
        // Try to detect specific string types
        if (/^\d{4}-\d{2}-\d{2}/.test(value)) return 'timestamp';
        if (/^[a-f0-9-]{36}$/i.test(value)) return 'uuid';
        return 'text';
    }
    return typeof value;
}

/**
 * Generate a Markdown summary of the schema
 */
function generateMarkdownSummary(schema: DatabaseSchema): string {
    const lines: string[] = [
        '# Database Schema',
        '',
        `> **Exported at:** ${schema.exported_at}`,
        `> **Export method:** ${schema.export_method}`,
        `> **Supabase:** ${schema.supabase_url}`,
        '',
        '---',
        '',
        '## Tables',
        ''
    ];

    // Tables section
    for (const table of schema.tables || []) {
        const status = table.accessible === false ? '❌' : '✅';
        lines.push(`### ${status} \`${table.table_name}\``);
        lines.push('');

        if (table.columns && table.columns.length > 0) {
            lines.push('| Column | Type | PK | Foreign Key |');
            lines.push('|--------|------|----|-------------|');
            for (const col of table.columns) {
                const pk = col.is_primary_key ? 'PK' : '';
                const fkRef = col.foreign_key
                    ? `→ \`${col.foreign_key.foreign_table}.${col.foreign_key.foreign_column}\``
                    : '';
                lines.push(`| \`${col.column_name}\` | ${col.data_type} | ${pk} | ${fkRef} |`);
            }
        } else if (table.error) {
            lines.push(`> ⚠️ Error: ${table.error}`);
        } else {
            lines.push('> No columns found');
        }
        lines.push('');
    }

    // Views section
    lines.push('---', '', '## Views', '');

    for (const view of schema.views || []) {
        const status = view.accessible === false ? '❌' : '✅';
        lines.push(`### ${status} \`${view.view_name}\``);
        lines.push('');

        if (view.columns && view.columns.length > 0) {
            lines.push('| Column | Type | PK | Foreign Key |');
            lines.push('|--------|------|----|-------------|');
            for (const col of view.columns) {
                const pk = col.is_primary_key ? 'PK' : '';
                const fkRef = col.foreign_key
                    ? `→ \`${col.foreign_key.foreign_table}.${col.foreign_key.foreign_column}\``
                    : '';
                lines.push(`| \`${col.column_name}\` | ${col.data_type} | ${pk} | ${fkRef} |`);
            }
        } else if (view.view_definition) {
            lines.push('```sql');
            lines.push(view.view_definition);
            lines.push('```');
        } else if (view.error) {
            lines.push(`> ⚠️ Error: ${view.error}`);
        }
        lines.push('');
    }

    // Functions section (if available)
    if (schema.functions && schema.functions.length > 0) {
        lines.push('---', '', '## Functions', '');
        lines.push('| Function | Return Type | Arguments |');
        lines.push('|----------|-------------|-----------|');
        for (const func of schema.functions) {
            const args = func.arguments || '-';
            lines.push(`| \`${func.function_name}\` | ${func.return_type} | ${args} |`);
        }
        lines.push('');
    }

    // Policies section (if available)
    if (schema.policies && schema.policies.length > 0) {
        lines.push('---', '', '## RLS Policies', '');
        lines.push('| Table | Policy | Command |');
        lines.push('|-------|--------|---------|');
        for (const policy of schema.policies) {
            lines.push(`| \`${policy.table_name}\` | ${policy.policy_name} | ${policy.command} |`);
        }
        lines.push('');
    }

    // Indexes section (if available)
    if (schema.indexes && schema.indexes.length > 0) {
        lines.push('---', '', '## Indexes', '');
        lines.push('| Index | Table |');
        lines.push('|-------|-------|');
        for (const idx of schema.indexes) {
            lines.push(`| \`${idx.index_name}\` | \`${idx.table_name}\` |`);
        }
        lines.push('');
    }

    // Table stats section (if available)
    if (schema.table_stats && schema.table_stats.length > 0) {
        lines.push('---', '', '## Table Statistics', '');
        lines.push('| Table | Estimated Rows | Size |');
        lines.push('|-------|----------------|------|');
        for (const stat of schema.table_stats) {
            const size = stat.total_size_bytes
                ? formatBytes(stat.total_size_bytes)
                : '-';
            lines.push(`| \`${stat.table_name}\` | ${stat.estimated_rows || 0} | ${size} |`);
        }
        lines.push('');
    }

    return lines.join('\n');
}

/**
 * Format bytes to human readable string
 */
function formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

/**
 * Generate SQL file containing all database functions with their full definitions
 */
function generateFunctionsSql(schema: DatabaseSchema): string {
    const lines: string[] = [];

    lines.push('-- Database Functions Export');
    lines.push(`-- Exported at: ${schema.exported_at}`);
    lines.push(`-- Source: ${schema.supabase_url}`);
    lines.push(`-- Total functions: ${schema.functions?.length || 0}`);
    lines.push('');
    lines.push('-- =============================================================================');
    lines.push('-- FUNCTIONS');
    lines.push('-- =============================================================================');
    lines.push('');

    // Group functions by type for better organization
    const rlsHelpers = (schema.functions || []).filter(fn =>
        fn.function_name.startsWith('current_') ||
        fn.function_name.startsWith('is_') ||
        fn.function_name.includes('escola') ||
        fn.function_name.includes('admin')
    );
    const otherFunctions = (schema.functions || []).filter(fn => !rlsHelpers.includes(fn));

    if (rlsHelpers.length > 0) {
        lines.push('-- -----------------------------------------------------------------------------');
        lines.push('-- RLS Helper Functions');
        lines.push('-- -----------------------------------------------------------------------------');
        lines.push('');

        for (const fn of rlsHelpers) {
            lines.push(`-- Function: ${fn.function_name}`);
            lines.push(`-- Return type: ${fn.return_type}`);
            lines.push(`-- Arguments: ${fn.arguments || '(none)'}`);
            lines.push(`-- Volatility: ${fn.volatility || 'unknown'}`);
            lines.push(`-- Security definer: ${fn.security_definer ? 'YES' : 'NO'}`);
            lines.push('');

            if (fn.definition) {
                const def = fn.definition.trim();
                lines.push(def.endsWith(';') ? def : `${def};`);
            } else {
                lines.push(`-- Definition not available`);
            }
            lines.push('');
        }
    }

    if (otherFunctions.length > 0) {
        lines.push('-- -----------------------------------------------------------------------------');
        lines.push('-- Other Functions');
        lines.push('-- -----------------------------------------------------------------------------');
        lines.push('');

        for (const fn of otherFunctions) {
            lines.push(`-- Function: ${fn.function_name}`);
            lines.push(`-- Return type: ${fn.return_type}`);
            lines.push(`-- Arguments: ${fn.arguments || '(none)'}`);
            lines.push(`-- Volatility: ${fn.volatility || 'unknown'}`);
            lines.push(`-- Security definer: ${fn.security_definer ? 'YES' : 'NO'}`);
            lines.push('');

            if (fn.definition) {
                const def = fn.definition.trim();
                lines.push(def.endsWith(';') ? def : `${def};`);
            } else {
                lines.push(`-- Definition not available`);
            }
            lines.push('');
        }
    }

    lines.push('-- =============================================================================');
    lines.push(`-- End of functions export (${schema.functions?.length || 0} total)`);
    lines.push('-- =============================================================================');

    return lines.join('\n');
}

/**
 * Generate SQL file containing all triggers with their function definitions
 */
function generateTriggersSql(schema: DatabaseSchema): string {
    const lines: string[] = [];

    lines.push('-- Database Triggers Export');
    lines.push(`-- Exported at: ${schema.exported_at}`);
    lines.push(`-- Source: ${schema.supabase_url}`);
    lines.push(`-- Total triggers: ${schema.triggers?.length || 0}`);
    lines.push('');
    lines.push('-- =============================================================================');
    lines.push('-- TRIGGERS AND TRIGGER FUNCTIONS');
    lines.push('-- =============================================================================');
    lines.push('');

    // First, output all unique trigger functions
    const seenFunctions = new Set<string>();
    const triggerFunctions: TriggerInfo[] = [];

    for (const trigger of schema.triggers || []) {
        if (trigger.trigger_function_definition && !seenFunctions.has(trigger.trigger_function_name || '')) {
            seenFunctions.add(trigger.trigger_function_name || '');
            triggerFunctions.push(trigger);
        }
    }

    if (triggerFunctions.length > 0) {
        lines.push('-- -----------------------------------------------------------------------------');
        lines.push('-- Trigger Functions');
        lines.push('-- -----------------------------------------------------------------------------');
        lines.push('');

        for (const trigger of triggerFunctions) {
            lines.push(`-- Function: ${trigger.trigger_function_schema}.${trigger.trigger_function_name}`);
            lines.push(`-- Used by trigger: ${trigger.trigger_name} on ${trigger.table_name || trigger.event_object_table}`);
            lines.push('');

            if (trigger.trigger_function_definition) {
                const def = trigger.trigger_function_definition.trim();
                lines.push(def.endsWith(';') ? def : `${def};`);
            }
            lines.push('');
        }
    }

    // Then output all triggers
    if ((schema.triggers || []).length > 0) {
        lines.push('-- -----------------------------------------------------------------------------');
        lines.push('-- Triggers');
        lines.push('-- -----------------------------------------------------------------------------');
        lines.push('');

        for (const trigger of schema.triggers || []) {
            const tableName = trigger.table_name || trigger.event_object_table;
            lines.push(`-- Trigger: ${trigger.trigger_name}`);
            lines.push(`-- Table: ${tableName}`);
            lines.push(`-- Type: ${trigger.trigger_type || trigger.action_timing} ${trigger.trigger_events || trigger.event_manipulation}`);
            lines.push(`-- For each: ${trigger.for_each || trigger.action_orientation}`);
            lines.push(`-- Enabled: ${trigger.is_enabled !== false ? 'YES' : 'NO'}`);
            if (trigger.condition) {
                lines.push(`-- Condition: ${trigger.condition}`);
            }
            lines.push('');

            if (trigger.trigger_definition) {
                const def = trigger.trigger_definition.trim();
                lines.push(def.endsWith(';') ? def : `${def};`);
            } else if (trigger.action_statement) {
                // Fall back to building the trigger from parts
                const timing = trigger.action_timing || trigger.trigger_type || 'AFTER';
                const events = trigger.event_manipulation || trigger.trigger_events || 'INSERT';
                const forEach = trigger.action_orientation || trigger.for_each || 'ROW';
                lines.push(`CREATE TRIGGER ${trigger.trigger_name}`);
                lines.push(`    ${timing} ${events}`);
                lines.push(`    ON public."${tableName}"`);
                lines.push(`    FOR EACH ${forEach}`);
                lines.push(`    ${trigger.action_statement};`);
            }
            lines.push('');
        }
    }

    lines.push('-- =============================================================================');
    lines.push(`-- End of triggers export (${schema.triggers?.length || 0} triggers)`);
    lines.push('-- =============================================================================');

    return lines.join('\n');
}

/**
 * Generate SQL file containing only RLS policies
 */
function generateRlsPoliciesSql(schema: DatabaseSchema): string {
    const lines: string[] = [];

    lines.push('-- RLS Policies Export');
    lines.push(`-- Exported at: ${schema.exported_at}`);
    lines.push(`-- Source: ${schema.supabase_url}`);
    lines.push('');
    lines.push('-- =============================================================================');
    lines.push('-- ENABLE ROW LEVEL SECURITY');
    lines.push('-- =============================================================================');
    lines.push('');

    // Get unique tables that have policies
    const tablesWithPolicies = [...new Set((schema.policies || []).map(p => p.table_name))].sort();

    for (const tableName of tablesWithPolicies) {
        lines.push(`ALTER TABLE public.${toSqlIdentifier(tableName)} ENABLE ROW LEVEL SECURITY;`);
    }

    if (tablesWithPolicies.length > 0) {
        lines.push('');
        lines.push('-- =============================================================================');
        lines.push('-- DROP EXISTING POLICIES (optional - uncomment if needed)');
        lines.push('-- =============================================================================');
        lines.push('');
    }

    // Generate DROP statements (commented out by default)
    for (const policy of schema.policies || []) {
        lines.push(`-- DROP POLICY IF EXISTS ${toSqlIdentifier(policy.policy_name)} ON public.${toSqlIdentifier(policy.table_name)};`);
    }

    if ((schema.policies || []).length > 0) {
        lines.push('');
        lines.push('-- =============================================================================');
        lines.push('-- CREATE POLICIES');
        lines.push('-- =============================================================================');
        lines.push('');
    }

    // Group policies by table for better organization
    const policiesByTable = new Map<string, PolicyInfo[]>();
    for (const policy of schema.policies || []) {
        const existing = policiesByTable.get(policy.table_name) || [];
        existing.push(policy);
        policiesByTable.set(policy.table_name, existing);
    }

    for (const [tableName, policies] of [...policiesByTable.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
        lines.push(`-- Table: ${tableName}`);
        lines.push('');

        for (const policy of policies) {
            const permissive = policy.permissive || 'PERMISSIVE';
            const command = policy.command || 'ALL';

            lines.push(`CREATE POLICY ${toSqlIdentifier(policy.policy_name)}`);
            lines.push(`    ON public.${toSqlIdentifier(tableName)}`);
            lines.push(`    AS ${permissive}`);
            lines.push(`    FOR ${command}`);
            lines.push(`    TO authenticated`);

            if (policy.using_expression) {
                lines.push(`    USING (${policy.using_expression.trim()})`);
            }

            if (policy.with_check_expression) {
                lines.push(`    WITH CHECK (${policy.with_check_expression.trim()})`);
            }

            lines.push(';');
            lines.push('');
        }
    }

    // Summary at the end
    lines.push('-- =============================================================================');
    lines.push(`-- Total: ${schema.policies?.length || 0} policies across ${tablesWithPolicies.length} tables`);
    lines.push('-- =============================================================================');

    return lines.join('\n');
}

function toSqlIdentifier(identifier: string): string {
    return `"${identifier.replace(/"/g, '""')}"`;
}

function normalizeSqlDefault(defaultValue: string): string {
    const trimmed = defaultValue.trim();

    // Keep common SQL expressions as-is.
    if (
        trimmed === 'now()' ||
        trimmed === 'CURRENT_TIMESTAMP' ||
        trimmed === 'current_timestamp' ||
        trimmed.startsWith('nextval(') ||
        trimmed.includes('::') ||
        trimmed.endsWith('()')
    ) {
        return trimmed;
    }

    // If already quoted, leave it.
    if ((trimmed.startsWith("'") && trimmed.endsWith("'")) || (trimmed.startsWith('"') && trimmed.endsWith('"'))) {
        return trimmed;
    }

    // Otherwise, quote as a literal.
    return `'${trimmed.replace(/'/g, "''")}'`;
}

function formatMigrationTimestamp(date: Date): string {
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}${pad(date.getUTCHours())}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}`;
}

function generateSupabaseBaselineMigrationSql(schema: DatabaseSchema): string {
    const lines: string[] = [];

    lines.push('-- Auto-generated migration from backend/scripts/export_schema.ts');
    lines.push(`-- Exported at: ${schema.exported_at}`);
    lines.push('-- NOTE: This is a best-effort baseline for local Supabase tests.');
    lines.push(`-- Includes: ${schema.tables?.length || 0} tables, ${schema.views?.length || 0} views, ${schema.functions?.length || 0} functions, ${schema.triggers?.length || 0} triggers, ${schema.policies?.length || 0} policies`);
    lines.push('');
    lines.push('BEGIN;');
    lines.push('');

    // Extensions commonly used by the schema
    const hasUnaccent = (schema.functions || []).some((f) => f.function_name === 'unaccent' || f.function_name.startsWith('unaccent'));
    if (hasUnaccent) {
        lines.push('CREATE EXTENSION IF NOT EXISTS unaccent;');
        lines.push('');
    }

    // Collect sequences referenced in column defaults (must be created before tables)
    const sequencesNeeded = new Set<string>();
    for (const table of schema.tables || []) {
        if (!table.table_name || table.table_type !== 'BASE TABLE') continue;
        for (const col of table.columns || []) {
            if (col.column_default && col.column_default.includes('nextval(')) {
                const match = col.column_default.match(/nextval\('([^']+)'/);
                if (match && match[1]) {
                    sequencesNeeded.add(match[1].replace('::regclass', ''));
                }
            }
        }
    }

    // Create sequences before tables
    if (sequencesNeeded.size > 0) {
        lines.push('-- Sequences (created before tables that reference them)');
        for (const seqName of sequencesNeeded) {
            const fullName = seqName.includes('.') ? seqName : `public.${seqName}`;
            lines.push(`CREATE SEQUENCE IF NOT EXISTS ${fullName};`);
        }
        lines.push('');
    }

    // Create tables
    for (const table of schema.tables || []) {
        if (!table.table_name || table.table_type !== 'BASE TABLE') continue;

        const tableName = `public.${toSqlIdentifier(table.table_name)}`;
        lines.push(`CREATE TABLE IF NOT EXISTS ${tableName} (`);

        const columnLines: string[] = [];
        for (const col of table.columns || []) {
            const parts: string[] = [];
            parts.push(toSqlIdentifier(col.column_name));

            // Fix bare ARRAY type - PostgreSQL needs element type like text[]
            let dataType = col.data_type;
            if (dataType.toUpperCase() === 'ARRAY') {
                dataType = 'text[]'; // Default to text[] when element type unknown
            }
            parts.push(dataType);

            const isIdentity = col.is_identity === 'YES';
            if (isIdentity) {
                parts.push('GENERATED BY DEFAULT AS IDENTITY');
            }

            if (!isIdentity && col.column_default && col.column_default !== 'null') {
                parts.push(`DEFAULT ${normalizeSqlDefault(col.column_default)}`);
            }

            if (col.is_nullable === 'NO') {
                parts.push('NOT NULL');
            }

            columnLines.push(`  ${parts.join(' ')}`);
        }

        lines.push(columnLines.join(',\n'));
        lines.push(');');
        lines.push('');
    }

    // Primary keys
    const pkByTable = new Map<string, { constraint_name: string; columns: string[] }>();
    for (const pk of schema.primary_keys || []) {
        const existing = pkByTable.get(pk.table_name);
        if (!existing) {
            pkByTable.set(pk.table_name, { constraint_name: pk.constraint_name, columns: [pk.column_name] });
        } else {
            existing.columns.push(pk.column_name);
        }
    }
    for (const [tableName, pk] of pkByTable.entries()) {
        const cols = pk.columns.map((c) => toSqlIdentifier(c)).join(', ');
        lines.push(`ALTER TABLE ONLY public.${toSqlIdentifier(tableName)} ADD CONSTRAINT ${toSqlIdentifier(pk.constraint_name)} PRIMARY KEY (${cols});`);
    }
    if (pkByTable.size > 0) lines.push('');

    // Foreign keys
    for (const fk of schema.foreign_keys || []) {
        lines.push(
            `ALTER TABLE ONLY public.${toSqlIdentifier(fk.table_name)} ADD CONSTRAINT ${toSqlIdentifier(fk.constraint_name)} FOREIGN KEY (${toSqlIdentifier(fk.column_name)}) REFERENCES public.${toSqlIdentifier(fk.foreign_table_name)}(${toSqlIdentifier(fk.foreign_column_name)});`
        );
    }
    if ((schema.foreign_keys || []).length > 0) lines.push('');

    // Views
    for (const view of schema.views || []) {
        if (!view.view_name || !view.view_definition) continue;
        const viewDef = view.view_definition.trim().replace(/;\s*$/, '');
        lines.push(`CREATE OR REPLACE VIEW public.${toSqlIdentifier(view.view_name)} AS ${viewDef};`);
        lines.push('');
    }

    // Materialized views (needed before creating indexes on them)
    for (const mv of schema.materialized_views || []) {
        if (!mv.view_name || !mv.view_definition) continue;
        const mvDef = mv.view_definition.trim().replace(/;\s*$/, '');
        lines.push(`DROP MATERIALIZED VIEW IF EXISTS public.${toSqlIdentifier(mv.view_name)};`);
        lines.push(`CREATE MATERIALIZED VIEW public.${toSqlIdentifier(mv.view_name)} AS ${mvDef} WITH NO DATA;`);
        lines.push('');
    }

    // Indexes (skip PK indexes which are created by PRIMARY KEY constraints)
    const pkIndexNames = new Set<string>();
    for (const pk of schema.primary_keys || []) {
        pkIndexNames.add(pk.constraint_name);
    }
    for (const idx of schema.indexes || []) {
        if (pkIndexNames.has(idx.index_name)) continue;
        lines.push(`${idx.index_definition};`);
    }
    if ((schema.indexes || []).length > 0) lines.push('');

    // Functions (must come before RLS policies and triggers that reference them)
    const functionsWithDefinitions = (schema.functions || []).filter(fn => fn.definition);
    if (functionsWithDefinitions.length > 0) {
        lines.push('-- =============================================================================');
        lines.push('-- FUNCTIONS (RLS helper functions and other custom functions)');
        lines.push('-- =============================================================================');
        lines.push('');

        for (const fn of functionsWithDefinitions) {
            // The definition from pg_get_functiondef already includes CREATE OR REPLACE
            const def = fn.definition?.trim();
            if (def) {
                // Ensure it ends with semicolon
                lines.push(def.endsWith(';') ? def : `${def};`);
                lines.push('');
            }
        }
    }

    // Triggers (after functions since triggers reference trigger functions)
    // First output trigger functions that aren't already in the functions list
    const seenFunctionNames = new Set(functionsWithDefinitions.map(f => f.function_name));
    const triggerFunctionsToAdd: TriggerInfo[] = [];

    for (const trigger of schema.triggers || []) {
        if (trigger.trigger_function_definition &&
            trigger.trigger_function_name &&
            !seenFunctionNames.has(trigger.trigger_function_name)) {
            seenFunctionNames.add(trigger.trigger_function_name);
            triggerFunctionsToAdd.push(trigger);
        }
    }

    if (triggerFunctionsToAdd.length > 0) {
        lines.push('-- =============================================================================');
        lines.push('-- TRIGGER FUNCTIONS');
        lines.push('-- =============================================================================');
        lines.push('');

        for (const trigger of triggerFunctionsToAdd) {
            const def = trigger.trigger_function_definition?.trim();
            if (def) {
                lines.push(def.endsWith(';') ? def : `${def};`);
                lines.push('');
            }
        }
    }

    // Now output the triggers themselves
    const triggersWithDefinitions = (schema.triggers || []).filter(t => t.trigger_definition);
    if (triggersWithDefinitions.length > 0) {
        lines.push('-- =============================================================================');
        lines.push('-- TRIGGERS');
        lines.push('-- =============================================================================');
        lines.push('');

        for (const trigger of triggersWithDefinitions) {
            const def = trigger.trigger_definition?.trim();
            if (def) {
                lines.push(def.endsWith(';') ? def : `${def};`);
                lines.push('');
            }
        }
    }

    // RLS policies - now we can include all since functions are defined above
    const policyTables = new Set((schema.policies || []).map((p) => p.table_name));
    for (const tableName of policyTables) {
        lines.push(`ALTER TABLE public.${toSqlIdentifier(tableName)} ENABLE ROW LEVEL SECURITY;`);
    }
    if (policyTables.size > 0) lines.push('');

    for (const policy of schema.policies || []) {
        const usingExpr = policy.using_expression?.trim() || 'true';
        const withCheckExpr = policy.with_check_expression?.trim();
        const checkClause = withCheckExpr ? ` WITH CHECK (${withCheckExpr})` : '';
        lines.push(
            `CREATE POLICY ${toSqlIdentifier(policy.policy_name)} ON public.${toSqlIdentifier(policy.table_name)} AS ${policy.permissive || 'PERMISSIVE'} FOR ${policy.command} TO authenticated USING (${usingExpr})${checkClause};`
        );
    }
    if ((schema.policies || []).length > 0) lines.push('');

    lines.push('COMMIT;');
    lines.push('');
    return lines.join('\n');
}

/**
 * Main export function
 */
export async function exportSchema(): Promise<DatabaseSchema> {
    console.log('');
    console.log('🚀 Starting database schema export...');
    console.log(`📁 Output directory: ${OUTPUT_DIR}`);
    console.log('');

    // Ensure output directory exists
    if (!fs.existsSync(OUTPUT_DIR)) {
        fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    }

    let schema: DatabaseSchema;

    try {
        // First, try using the RPC function (gives complete schema)
        const rpcResult = await exportViaRPC();

        if (rpcResult) {
            schema = rpcResult;
        } else {
            // Fallback to direct queries (limited but works without setup)
            schema = await exportViaDirectQueries();
        }

        // The RPC export provides PK/FK lists at the top level; enrich columns so
        // Markdown output can display PK and FK indicators per column.
        enrichColumnsWithPrimaryAndForeignKeys(schema);

        // Save JSON
        fs.writeFileSync(OUTPUT_FILE, JSON.stringify(schema, null, 2));
        console.log('');
        console.log(`✅ JSON schema saved to: ${OUTPUT_FILE}`);

        // Generate and save Markdown summary
        const markdown = generateMarkdownSummary(schema);
        fs.writeFileSync(OUTPUT_FILE_TABLES, markdown);
        console.log(`✅ Markdown summary saved to: ${OUTPUT_FILE_TABLES}`);

        // Generate and save RLS policies SQL
        const rlsSql = generateRlsPoliciesSql(schema);
        fs.writeFileSync(OUTPUT_FILE_RLS, rlsSql);
        console.log(`✅ RLS policies SQL saved to: ${OUTPUT_FILE_RLS}`);

        // Generate and save Functions SQL (if any functions were exported)
        if (schema.functions && schema.functions.length > 0) {
            const functionsSql = generateFunctionsSql(schema);
            fs.writeFileSync(OUTPUT_FILE_FUNCTIONS, functionsSql);
            console.log(`✅ Database functions SQL saved to: ${OUTPUT_FILE_FUNCTIONS}`);
        }

        // Generate and save Triggers SQL (if any triggers were exported)
        if (schema.triggers && schema.triggers.length > 0) {
            const triggersSql = generateTriggersSql(schema);
            fs.writeFileSync(OUTPUT_FILE_TRIGGERS, triggersSql);
            console.log(`✅ Database triggers SQL saved to: ${OUTPUT_FILE_TRIGGERS}`);
        }

        // Optional: generate a baseline migration for Supabase local tests
        const cliOptions = parseCliArgs(process.argv);
        if (true) {
            const outDir = cliOptions.migrationOutDir
                ? path.resolve(process.cwd(), cliOptions.migrationOutDir)
                : DEFAULT_MIGRATIONS_OUT_DIR;

            const basename = cliOptions.migrationBasename || DEFAULT_MIGRATION_BASENAME;
            if (!fs.existsSync(outDir)) {
                fs.mkdirSync(outDir, { recursive: true });
            }

            const migrationSql = generateSupabaseBaselineMigrationSql(schema);
            const latestPath = path.join(outDir, basename);
            fs.writeFileSync(latestPath, migrationSql);

            /* const tsName = `${formatMigrationTimestamp(new Date(schema.exported_at))}_init_from_export.sql`;
            const timestampedPath = path.join(outDir, tsName);
            fs.writeFileSync(timestampedPath, migrationSql); */

            console.log(`✅ Supabase baseline migration saved to: ${latestPath}`);

            // Also copy to the main supabase/migrations folder for actual deployment
            const supabaseMigrationsDir = path.join(__dirname, '..', '..', '..', 'supabase', 'migrations');
            const supabaseMigrationPath = path.join(supabaseMigrationsDir, '000_init_from_export.sql');
            if (fs.existsSync(supabaseMigrationsDir)) {
                fs.writeFileSync(supabaseMigrationPath, migrationSql);
                console.log(`✅ Supabase migration also copied to: ${supabaseMigrationPath}`);
            }
            //console.log(`✅ Supabase baseline migration (timestamped) saved to: ${timestampedPath}`);
        }

        // Print summary
        console.log('');
        console.log('═══════════════════════════════════════════════');
        console.log('📊 SCHEMA EXPORT SUMMARY');
        console.log('═══════════════════════════════════════════════');
        console.log(`   Method:       ${schema.export_method}`);
        console.log(`   Tables:       ${schema.tables?.length || 0}`);
        console.log(`   Views:        ${schema.views?.length || 0}`);
        console.log(`   Functions:    ${schema.functions?.length || 0}`);
        console.log(`   Triggers:     ${schema.triggers?.length || 0}`);
        console.log(`   Foreign Keys: ${schema.foreign_keys?.length || 0}`);
        console.log(`   Indexes:      ${schema.indexes?.length || 0}`);
        console.log(`   Policies:     ${schema.policies?.length || 0}`);
        console.log(`   Enums:        ${schema.enums?.length || 0}`);
        console.log('═══════════════════════════════════════════════');

        return schema;

    } catch (error) {
        console.error('');
        console.error('❌ Error exporting schema:', error);
        throw error;
    }
}

// Run if called directly (ESM-compatible check)
const isMainModule = import.meta.url === `file://${process.argv[1]}`;
if (isMainModule) {
    exportSchema()
        .then(() => {
            console.log('');
            console.log('✅ Export complete!');
            process.exit(0);
        })
        .catch((error) => {
            console.error('❌ Export failed:', error);
            process.exit(1);
        });
}
