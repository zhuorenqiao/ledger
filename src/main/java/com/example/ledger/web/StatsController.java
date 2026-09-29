package com.example.ledger.web;

import com.example.ledger.dto.SummaryResponse;
import com.example.ledger.dto.TrendPoint;
import com.example.ledger.security.AuthUser;
import com.example.ledger.service.StatsService;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/stats")
public class StatsController {

  private final StatsService stats;

  public StatsController(StatsService stats) {
    this.stats = stats;
  }

  /** 区间收支合计与分类构成，from/to 省略时为全部历史。 */
  @GetMapping("/summary")
  public SummaryResponse summary(@AuthenticationPrincipal AuthUser me,
      @RequestParam(required = false) String from,
      @RequestParam(required = false) String to) {
    RequestValidation.requireDayFormat(from);
    RequestValidation.requireDayFormat(to);
    return stats.summary(me.id(), from, to);
  }

  /** 指定月份的每日趋势，横轴覆盖整月（无记录的日期为 0）。 */
  @GetMapping("/daily")
  public List<TrendPoint> daily(@AuthenticationPrincipal AuthUser me,
      @RequestParam int year, @RequestParam int month) {
    if (month < 1 || month > 12) {
      throw badRequest("month 必须在 1 到 12 之间");
    }
    return stats.daily(me.id(), year, month);
  }

  /** 指定年份的 12 个月趋势。 */
  @GetMapping("/monthly")
  public List<TrendPoint> monthly(@AuthenticationPrincipal AuthUser me, @RequestParam int year) {
    return stats.monthly(me.id(), year);
  }

  @GetMapping("/years")
  public List<Integer> years(@AuthenticationPrincipal AuthUser me) {
    return stats.years(me.id());
  }

  private static ApiException badRequest(String message) {
    return new ApiException(ErrorCode.PARAM_INVALID, message);
  }
}
