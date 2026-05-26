// 主题类型枚举
export enum ColorTheme {
  DEFAULT = 'default',      // 默认暖纸
  CLAUDE = 'claude',        // Claude 暖棕
  CHATGPT = 'chatgpt',      // 清爽蓝
  VIOLET = 'violet',        // 雾紫
  MINT = 'mint',            // 松雾绿
  NOTION = 'notion',        // Notion 极简
  CLASSIC_BLUE = 'classic_blue', // 经典复刻
  OBSIDIAN = 'obsidian'     // 曜石灰
}

// 主题颜色配置接口
export interface ThemeColorConfig {
  // 主色调
  primary: string
  primaryLight: string
  // 背景色
  background: string
  // 表面色
  surface: string
  // 分隔线
  divider: string
  // 用户气泡
  userBubble: string
  userBubbleText: string
  // AI 气泡
  aiBubble: string
  // 文字颜色
  textPrimary: string
  textSecondary: string
  textTertiary: string
  // Markdown 相关
  markdownTitle: string
  markdownText: string
  markdownLink: string
  markdownLinkBg: string
  markdownCodeBg: string
  markdownCodeText: string
  markdownQuoteBg: string
  markdownTableBg: string
  markdownTableHeaderBg: string
  markdownTableAltBg: string
  markdownTableBorder: string
}

// 主题信息接口
export interface ThemeInfo {
  id: ColorTheme
  nameKey: string           // 字符串资源 key
  descriptionKey: string    // 描述字符串资源 key
  previewColors: string[]   // 预览色块（4 个颜色：背景、弱染色、主色、气泡）
  light: ThemeColorConfig
  dark: ThemeColorConfig
}

// 默认暖纸主题：中性色底盘，蓝灰只做小面积强调。
const DEFAULT_THEME: ThemeInfo = {
  id: ColorTheme.DEFAULT,
  nameKey: 'theme_color_default',
  descriptionKey: 'theme_color_default_desc',
  previewColors: ['#FAF8F3', '#D8E2EE', '#4E6F9E', '#52688A'],
  light: {
    primary: '#4E6F9E',
    primaryLight: '#D8E2EE',
    background: '#FAF8F3',
    surface: '#FFFDF8',
    divider: '#DED8CC',
    userBubble: '#52688A',
    userBubbleText: '#FFFFFF',
    aiBubble: '#FFFDF8',
    textPrimary: '#24211C',
    textSecondary: '#6F6A60',
    textTertiary: '#8A8178',
    markdownTitle: '#24211C',
    markdownText: '#3D3830',
    markdownLink: '#4E6F9E',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#F3EFE8',
    markdownCodeText: '#8F5E45',
    markdownQuoteBg: '#F3EFE8',
    markdownTableBg: '#FFFDF8',
    markdownTableHeaderBg: '#F3EFE8',
    markdownTableAltBg: '#FAF7F0',
    markdownTableBorder: '#DED8CC'
  },
  dark: {
    primary: '#7FA2CC',
    primaryLight: '#273646',
    background: '#1F1E1A',
    surface: '#292722',
    divider: '#403C34',
    userBubble: '#4F6886',
    userBubbleText: '#F7FAFD',
    aiBubble: '#292722',
    textPrimary: '#F3EFE6',
    textSecondary: '#B8B0A3',
    textTertiary: '#837B70',
    markdownTitle: '#F3EFE6',
    markdownText: '#E7E0D4',
    markdownLink: '#9CBFE8',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#24221E',
    markdownCodeText: '#D7C4A9',
    markdownQuoteBg: '#24221E',
    markdownTableBg: '#292722',
    markdownTableHeaderBg: '#332F28',
    markdownTableAltBg: '#2E2B25',
    markdownTableBorder: '#403C34'
  }
}

// Claude 暖棕主题：参考暖纸面和锈棕点缀，避免大面积橙色。
const CLAUDE_THEME: ThemeInfo = {
  id: ColorTheme.CLAUDE,
  nameKey: 'theme_color_claude',
  descriptionKey: 'theme_color_claude_desc',
  previewColors: ['#FAF7F0', '#F1E8E0', '#A65F3B', '#8F5E45'],
  light: {
    primary: '#A65F3B',
    primaryLight: '#F1E8E0',
    background: '#FAF7F0',
    surface: '#FFFDF8',
    divider: '#DED6CA',
    userBubble: '#8F5E45',
    userBubbleText: '#FFFFFF',
    aiBubble: '#FFFDF8',
    textPrimary: '#26211C',
    textSecondary: '#6F665C',
    textTertiary: '#9C9287',
    markdownTitle: '#26211C',
    markdownText: '#3F372F',
    markdownLink: '#A65F3B',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#F3EDE5',
    markdownCodeText: '#8F5E45',
    markdownQuoteBg: '#F3EDE5',
    markdownTableBg: '#FFFDF8',
    markdownTableHeaderBg: '#F3EDE5',
    markdownTableAltBg: '#FAF4EC',
    markdownTableBorder: '#DED6CA'
  },
  dark: {
    primary: '#C87552',
    primaryLight: '#3A2C25',
    background: '#251F1A',
    surface: '#292722',
    divider: '#403C34',
    userBubble: '#7A4E3D',
    userBubbleText: '#FFF8F2',
    aiBubble: '#292722',
    textPrimary: '#F3EFE6',
    textSecondary: '#B8B0A3',
    textTertiary: '#837B70',
    markdownTitle: '#F3EFE6',
    markdownText: '#E7E0D4',
    markdownLink: '#D48B68',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#24221E',
    markdownCodeText: '#E0AA8A',
    markdownQuoteBg: '#24221E',
    markdownTableBg: '#292722',
    markdownTableHeaderBg: '#332F28',
    markdownTableAltBg: '#2E2B25',
    markdownTableBorder: '#403C34'
  }
}

// 清爽蓝主题：保留冷静科技感，但降低蓝色饱和和面积。
const CHATGPT_THEME: ThemeInfo = {
  id: ColorTheme.CHATGPT,
  nameKey: 'theme_color_chatgpt',
  descriptionKey: 'theme_color_chatgpt_desc',
  previewColors: ['#F7FAFC', '#E4EDF6', '#416FAD', '#4D719C'],
  light: {
    primary: '#416FAD',
    primaryLight: '#E4EDF6',
    background: '#F7FAFC',
    surface: '#FCFEFF',
    divider: '#D9E0E7',
    userBubble: '#4D719C',
    userBubbleText: '#FFFFFF',
    aiBubble: '#FCFEFF',
    textPrimary: '#1F252B',
    textSecondary: '#64707A',
    textTertiary: '#8F9AA4',
    markdownTitle: '#1F252B',
    markdownText: '#34404A',
    markdownLink: '#416FAD',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#EDF3F7',
    markdownCodeText: '#47627F',
    markdownQuoteBg: '#EDF3F7',
    markdownTableBg: '#FCFEFF',
    markdownTableHeaderBg: '#EDF3F7',
    markdownTableAltBg: '#F4F8FA',
    markdownTableBorder: '#D9E0E7'
  },
  dark: {
    primary: '#82A9D4',
    primaryLight: '#24374A',
    background: '#182027',
    surface: '#202932',
    divider: '#34404A',
    userBubble: '#4D6F91',
    userBubbleText: '#F6FAFF',
    aiBubble: '#202932',
    textPrimary: '#EEF4FA',
    textSecondary: '#B1BCC7',
    textTertiary: '#7E8A96',
    markdownTitle: '#EEF4FA',
    markdownText: '#DDE6EE',
    markdownLink: '#9CBFE5',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#1B242C',
    markdownCodeText: '#C2CEDA',
    markdownQuoteBg: '#1B242C',
    markdownTableBg: '#202932',
    markdownTableHeaderBg: '#2A3540',
    markdownTableAltBg: '#242E38',
    markdownTableBorder: '#34404A'
  }
}

// 雾紫主题：紫色只做灰紫点缀，避免大面积高饱和紫。
const VIOLET_THEME: ThemeInfo = {
  id: ColorTheme.VIOLET,
  nameKey: 'theme_color_violet',
  descriptionKey: 'theme_color_violet_desc',
  previewColors: ['#FAF8FC', '#ECE8F2', '#7E5F92', '#675F82'],
  light: {
    primary: '#7E5F92',
    primaryLight: '#ECE8F2',
    background: '#FAF8FC',
    surface: '#FFFDFF',
    divider: '#DED8E5',
    userBubble: '#675F82',
    userBubbleText: '#FFFFFF',
    aiBubble: '#FFFDFF',
    textPrimary: '#27232C',
    textSecondary: '#6B6474',
    textTertiary: '#9B93A3',
    markdownTitle: '#27232C',
    markdownText: '#3F3948',
    markdownLink: '#71658F',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#F1EDF5',
    markdownCodeText: '#6E5D86',
    markdownQuoteBg: '#F1EDF5',
    markdownTableBg: '#FFFDFF',
    markdownTableHeaderBg: '#F1EDF5',
    markdownTableAltBg: '#FAF6FC',
    markdownTableBorder: '#DED8E5'
  },
  dark: {
    primary: '#A897C5',
    primaryLight: '#342D42',
    background: '#1F1D24',
    surface: '#2A2630',
    divider: '#40394A',
    userBubble: '#5F5476',
    userBubbleText: '#FBF8FF',
    aiBubble: '#2A2630',
    textPrimary: '#F1ECF7',
    textSecondary: '#B8AEC4',
    textTertiary: '#83778F',
    markdownTitle: '#F1ECF7',
    markdownText: '#E3DBEC',
    markdownLink: '#BEAFDA',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#25222B',
    markdownCodeText: '#D0C1E5',
    markdownQuoteBg: '#25222B',
    markdownTableBg: '#2A2630',
    markdownTableHeaderBg: '#352F3D',
    markdownTableAltBg: '#302B37',
    markdownTableBorder: '#40394A'
  }
}

// 松雾绿主题：偏自然的低饱和松绿色，避免荧光薄荷感。
const MINT_THEME: ThemeInfo = {
  id: ColorTheme.MINT,
  nameKey: 'theme_color_mint',
  descriptionKey: 'theme_color_mint_desc',
  previewColors: ['#F7FAF6', '#E5EFE9', '#4D8069', '#587A68'],
  light: {
    primary: '#4D8069',
    primaryLight: '#E5EFE9',
    background: '#F7FAF6',
    surface: '#FEFFFC',
    divider: '#D8E2D9',
    userBubble: '#587A68',
    userBubbleText: '#FFFFFF',
    aiBubble: '#FEFFFC',
    textPrimary: '#202820',
    textSecondary: '#627064',
    textTertiary: '#8C9A8E',
    markdownTitle: '#202820',
    markdownText: '#354238',
    markdownLink: '#4D8069',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#EEF4EF',
    markdownCodeText: '#4D705E',
    markdownQuoteBg: '#EEF4EF',
    markdownTableBg: '#FEFFFC',
    markdownTableHeaderBg: '#EEF4EF',
    markdownTableAltBg: '#F5F9F5',
    markdownTableBorder: '#D8E2D9'
  },
  dark: {
    primary: '#79A88F',
    primaryLight: '#25372D',
    background: '#1B211D',
    surface: '#242C26',
    divider: '#3A453C',
    userBubble: '#4E6F5C',
    userBubbleText: '#F6FFF9',
    aiBubble: '#242C26',
    textPrimary: '#EEF5EE',
    textSecondary: '#AFBBAF',
    textTertiary: '#7D8B80',
    markdownTitle: '#EEF5EE',
    markdownText: '#DDE8DE',
    markdownLink: '#91BAA3',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#202722',
    markdownCodeText: '#B9D1C2',
    markdownQuoteBg: '#202722',
    markdownTableBg: '#242C26',
    markdownTableHeaderBg: '#2E3730',
    markdownTableAltBg: '#29322B',
    markdownTableBorder: '#3A453C'
  }
}

// Notion 极简主题：纯白/深灰底，主界面保持黑白灰，链接保留小面积蓝色识别。
const NOTION_THEME: ThemeInfo = {
  id: ColorTheme.NOTION,
  nameKey: 'theme_color_notion',
  descriptionKey: 'theme_color_notion_desc',
  previewColors: ['#FFFFFF', '#F7F6F3', '#787774', '#37352F'],
  light: {
    primary: '#37352F',
    primaryLight: '#F1F1EF',
    background: '#FFFFFF',
    surface: '#FBFBFA',
    divider: '#E3E5E8',
    userBubble: '#37352F',
    userBubbleText: '#FFFFFF',
    aiBubble: '#F7F6F3',
    textPrimary: '#37352F',
    textSecondary: '#787774',
    textTertiary: '#9B9A97',
    markdownTitle: '#37352F',
    markdownText: '#37352F',
    markdownLink: '#2E7AC2',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#F7F6F3',
    markdownCodeText: '#EB5757',
    markdownQuoteBg: '#F7F6F3',
    markdownTableBg: '#FBFBFA',
    markdownTableHeaderBg: '#F7F6F3',
    markdownTableAltBg: '#FAFAF8',
    markdownTableBorder: '#E3E5E8'
  },
  dark: {
    primary: '#6F6E69',
    primaryLight: '#2F2F2F',
    background: '#191919',
    surface: '#202020',
    divider: '#373737',
    userBubble: '#3A3A3A',
    userBubbleText: '#FFFFFF',
    aiBubble: '#202020',
    textPrimary: '#FFFFFF',
    textSecondary: '#9B9A97',
    textTertiary: '#6F6E69',
    markdownTitle: '#FFFFFF',
    markdownText: '#E3E2E0',
    markdownLink: '#9DBAD7',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#2F2F2F',
    markdownCodeText: '#FF6B6B',
    markdownQuoteBg: '#2F2F2F',
    markdownTableBg: '#202020',
    markdownTableHeaderBg: '#2A2A2A',
    markdownTableAltBg: '#252525',
    markdownTableBorder: '#373737'
  }
}

// 经典复刻主题：纯白/纯黑底盘，复刻早期默认鸿蒙主色和蓝灰气泡。
const CLASSIC_BLUE_THEME: ThemeInfo = {
  id: ColorTheme.CLASSIC_BLUE,
  nameKey: 'theme_color_classic_blue',
  descriptionKey: 'theme_color_classic_blue_desc',
  previewColors: ['#FFFFFF', '#E8EEF2', '#4E6F9E', '#5A7597'],
  light: {
    primary: '#4E6F9E',
    primaryLight: '#E8EEF2',
    background: '#FFFFFF',
    surface: '#FFFFFF',
    divider: '#E5E7EB',
    userBubble: '#5A7597',
    userBubbleText: '#FFFFFF',
    aiBubble: '#FFFFFF',
    textPrimary: '#111827',
    textSecondary: '#4B5563',
    textTertiary: '#8B95A1',
    markdownTitle: '#111827',
    markdownText: '#2F3A46',
    markdownLink: '#4E6F9E',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#F3F4F6',
    markdownCodeText: '#6D4F3F',
    markdownQuoteBg: '#F7F8FA',
    markdownTableBg: '#FFFFFF',
    markdownTableHeaderBg: '#F3F4F6',
    markdownTableAltBg: '#FAFAFB',
    markdownTableBorder: '#E5E7EB'
  },
  dark: {
    primary: '#7FA2CC',
    primaryLight: '#1D2B3A',
    background: '#000000',
    surface: '#101010',
    divider: '#2A2A2A',
    userBubble: '#4F6886',
    userBubbleText: '#F7FAFD',
    aiBubble: '#101010',
    textPrimary: '#F5F5F5',
    textSecondary: '#C2C7D0',
    textTertiary: '#858B94',
    markdownTitle: '#F5F5F5',
    markdownText: '#E5E7EB',
    markdownLink: '#9CBFE8',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#181818',
    markdownCodeText: '#D7C4A9',
    markdownQuoteBg: '#181818',
    markdownTableBg: '#101010',
    markdownTableHeaderBg: '#181818',
    markdownTableAltBg: '#141414',
    markdownTableBorder: '#2A2A2A'
  }
}

// 曜石灰主题：纯黑白灰阶，给需要纯净深浅色对照的用户一个非蓝色选项。
const OBSIDIAN_THEME: ThemeInfo = {
  id: ColorTheme.OBSIDIAN,
  nameKey: 'theme_color_obsidian',
  descriptionKey: 'theme_color_obsidian_desc',
  previewColors: ['#F7F7F7', '#ECEDEF', '#52525B', '#3F3F46'],
  light: {
    primary: '#3F3F46',
    primaryLight: '#ECEDEF',
    background: '#F7F7F7',
    surface: '#FFFFFF',
    divider: '#E4E4E7',
    userBubble: '#3F3F46',
    userBubbleText: '#FFFFFF',
    aiBubble: '#FFFFFF',
    textPrimary: '#18181B',
    textSecondary: '#52525B',
    textTertiary: '#8A8A93',
    markdownTitle: '#18181B',
    markdownText: '#3F3F46',
    markdownLink: '#52525B',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#F0F0F2',
    markdownCodeText: '#3F3F46',
    markdownQuoteBg: '#F0F0F2',
    markdownTableBg: '#FFFFFF',
    markdownTableHeaderBg: '#F0F0F2',
    markdownTableAltBg: '#FAFAFA',
    markdownTableBorder: '#E4E4E7'
  },
  dark: {
    primary: '#71717A',
    primaryLight: '#27272A',
    background: '#000000',
    surface: '#111111',
    divider: '#2A2A2A',
    userBubble: '#3F3F46',
    userBubbleText: '#FFFFFF',
    aiBubble: '#111111',
    textPrimary: '#F4F4F5',
    textSecondary: '#C4C4CC',
    textTertiary: '#8A8A93',
    markdownTitle: '#F4F4F5',
    markdownText: '#E4E4E7',
    markdownLink: '#C4C4CC',
    markdownLinkBg: '#00000000',
    markdownCodeBg: '#18181B',
    markdownCodeText: '#D4D4D8',
    markdownQuoteBg: '#18181B',
    markdownTableBg: '#111111',
    markdownTableHeaderBg: '#18181B',
    markdownTableAltBg: '#151515',
    markdownTableBorder: '#2A2A2A'
  }
}

// 精简后的可选主题列表
export const ALL_THEMES: ThemeInfo[] = [
  DEFAULT_THEME,
  CLAUDE_THEME,
  CHATGPT_THEME,
  MINT_THEME,
  VIOLET_THEME,
  NOTION_THEME,
  CLASSIC_BLUE_THEME,
  OBSIDIAN_THEME
]

// 根据主题 ID 获取主题信息
export function getThemeById(themeId: ColorTheme): ThemeInfo {
  for (let i = 0; i < ALL_THEMES.length; i++) {
    if (ALL_THEMES[i].id === themeId) {
      return ALL_THEMES[i]
    }
  }
  return DEFAULT_THEME
}

// 根据主题 ID 和深浅模式获取颜色配置
export function getThemeColors(themeId: ColorTheme, isDarkMode: boolean): ThemeColorConfig {
  const theme = getThemeById(themeId)
  return isDarkMode ? theme.dark : theme.light
}
